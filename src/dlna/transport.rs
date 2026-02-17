use std::collections::HashMap;

use crate::dlna::metadata::didl_metadata;
use crate::dlna::types::{parse_duration, DlnaDevice, PlaybackState, PositionInfo};
use crate::error::AppError;

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

/// Build an XML payload from key-value pairs for SOAP actions.
fn xml_payload(pairs: &[(&str, &str)]) -> String {
    let mut s = String::new();
    for (key, value) in pairs {
        s.push('<');
        s.push_str(key);
        s.push('>');
        s.push_str(&xml_escape(value));
        s.push_str("</");
        s.push_str(key);
        s.push('>');
    }
    s
}

/// Resolve the AVTransport control URL for a device.
/// Fetches the device description XML and extracts the controlURL,
/// combining it with the URLBase or device URL authority.
pub async fn resolve_control_url(device: &DlnaDevice) -> Result<String, AppError> {
    let client = hyper014::Client::new();
    let device_url_str = device.device_url.to_string();
    let uri: http02::Uri = device_url_str
        .parse()
        .map_err(|e| AppError::DlnaAction(format!("Invalid device URL: {e}")))?;

    let response = client
        .get(uri.clone())
        .await
        .map_err(|e| AppError::DlnaAction(format!("Failed to fetch device description: {e}")))?;

    let body = hyper014::body::to_bytes(response.into_body())
        .await
        .map_err(|e| AppError::DlnaAction(format!("Failed to read device description: {e}")))?;

    let body_str = std::str::from_utf8(&body)
        .map_err(|e| AppError::DlnaAction(format!("Device description is not UTF-8: {e}")))?;

    // Extract URLBase if present, otherwise use device URL authority
    let base = if let Some(base_start) = body_str.find("<URLBase>") {
        let content = &body_str[base_start + "<URLBase>".len()..];
        let base_end = content
            .find("</URLBase>")
            .ok_or_else(|| AppError::DlnaAction("Malformed URLBase".into()))?;
        let base_url = content[..base_end].trim();
        base_url.trim_end_matches('/').to_string()
    } else {
        let scheme = uri.scheme_str().unwrap_or("http");
        let authority = uri
            .authority()
            .ok_or_else(|| AppError::DlnaAction("Device URL has no authority".into()))?
            .as_str();
        format!("{scheme}://{authority}")
    };

    // Find the AVTransport service block and extract controlURL
    let search = "urn:schemas-upnp-org:service:AVTransport:1";
    let type_pos = body_str
        .find(search)
        .ok_or_else(|| AppError::DlnaAction("AVTransport:1 not found in description".into()))?;

    let before = &body_str[..type_pos];
    let service_start = before
        .rfind("<service>")
        .ok_or_else(|| AppError::DlnaAction("No <service> block found".into()))?;
    let after_start = &body_str[service_start..];
    let service_end = after_start
        .find("</service>")
        .ok_or_else(|| AppError::DlnaAction("No </service> found".into()))?;
    let service_block = &after_start[..service_end];

    let control_tag = "<controlURL>";
    let control_start = service_block
        .find(control_tag)
        .ok_or_else(|| AppError::DlnaAction("No <controlURL> in AVTransport service".into()))?;
    let control_content = &service_block[control_start + control_tag.len()..];
    let control_end = control_content
        .find("</controlURL>")
        .ok_or_else(|| AppError::DlnaAction("No </controlURL> found".into()))?;
    let control_path = control_content[..control_end].trim();

    let url = if control_path.starts_with("http://") || control_path.starts_with("https://") {
        control_path.to_string()
    } else if control_path.starts_with('/') {
        format!("{base}{control_path}")
    } else {
        format!("{base}/{control_path}")
    };

    tracing::info!("Resolved AVTransport control URL: {url}");
    Ok(url)
}

/// Send a SOAP action directly via hyper, properly handling non-200 responses.
async fn soap_action(
    control_url: &str,
    service_type: &str,
    action: &str,
    payload: &str,
) -> Result<HashMap<String, String>, AppError> {
    let body = format!(
        r#"<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:{action} xmlns:u="{service_type}">
{payload}
</u:{action}>
</s:Body>
</s:Envelope>"#,
    );

    let soap_action_header = format!("\"{service_type}#{action}\"");

    let uri: http02::Uri = control_url
        .parse()
        .map_err(|e| AppError::DlnaAction(format!("Invalid control URL: {e}")))?;

    let req = http02::Request::builder()
        .method("POST")
        .uri(uri)
        .header("Content-Type", "text/xml; charset=\"utf-8\"")
        .header("SOAPAction", &soap_action_header)
        .body(hyper014::Body::from(body))
        .map_err(|e| AppError::DlnaAction(format!("Failed to build SOAP request: {e}")))?;

    let client = hyper014::Client::new();
    let response = client
        .request(req)
        .await
        .map_err(|e| AppError::DlnaAction(format!("{action} HTTP error: {e}")))?;

    let status = response.status();
    let body_bytes = hyper014::body::to_bytes(response.into_body())
        .await
        .map_err(|e| AppError::DlnaAction(format!("{action} read body error: {e}")))?;

    let body_str = String::from_utf8_lossy(&body_bytes);

    if !status.is_success() && status.as_u16() != 500 {
        return Err(AppError::DlnaAction(format!(
            "{action} returned {status}: {body_str}"
        )));
    }

    // Parse SOAP response to extract values or fault
    parse_soap_response(action, &body_str)
}

/// Parse a SOAP response body, extracting either the action response values or fault info.
fn parse_soap_response(
    action: &str,
    body: &str,
) -> Result<HashMap<String, String>, AppError> {
    // Check for SOAP fault
    if let Some(fault_pos) = body.find("<faultstring>") {
        let after = &body[fault_pos + "<faultstring>".len()..];
        let end = after.find("</faultstring>").unwrap_or(after.len().min(200));
        let fault_str = &after[..end];

        // Also try to extract UPnP error code
        let error_code = extract_between(body, "<errorCode>", "</errorCode>")
            .unwrap_or_default();
        let error_desc = extract_between(body, "<errorDescription>", "</errorDescription>")
            .unwrap_or_default();

        return Err(AppError::DlnaAction(format!(
            "{action} SOAP fault: {fault_str} (code: {error_code}, desc: {error_desc})"
        )));
    }

    // Extract response values from the action response element
    let response_tag = format!("{action}Response");
    let mut values = HashMap::new();

    if let Some(resp_pos) = body.find(&response_tag) {
        let after_resp = &body[resp_pos..];
        // Find all simple elements within the response
        let mut pos = 0;
        while pos < after_resp.len() {
            if let Some(tag_start) = after_resp[pos..].find('<') {
                let tag_start = pos + tag_start;
                if after_resp[tag_start..].starts_with("</") {
                    break; // closing tag of response element
                }
                if let Some(tag_end) = after_resp[tag_start..].find('>') {
                    let tag_end = tag_start + tag_end;
                    let tag_name = &after_resp[tag_start + 1..tag_end];
                    // Skip attributes
                    let tag_name = tag_name.split_whitespace().next().unwrap_or(tag_name);
                    if tag_name.starts_with('/') || tag_name.starts_with('?') {
                        pos = tag_end + 1;
                        continue;
                    }
                    let close_tag = format!("</{tag_name}>");
                    if let Some(close_pos) = after_resp[tag_end + 1..].find(&close_tag) {
                        let value = &after_resp[tag_end + 1..tag_end + 1 + close_pos];
                        values.insert(tag_name.to_string(), value.to_string());
                        pos = tag_end + 1 + close_pos + close_tag.len();
                    } else {
                        pos = tag_end + 1;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }

    Ok(values)
}

fn extract_between<'a>(s: &'a str, start_tag: &str, end_tag: &str) -> Option<&'a str> {
    let start = s.find(start_tag)? + start_tag.len();
    let end = s[start..].find(end_tag)?;
    Some(&s[start..start + end])
}

/// Set the media URI on the device and provide DIDL-Lite metadata.
pub async fn set_av_transport_uri(
    device: &DlnaDevice,
    control_url: &str,
    media_url: &str,
    title: &str,
    mime_type: &str,
    file_size: u64,
) -> Result<(), AppError> {
    let service_type = device.service.service_type().to_string();

    // Try with full DIDL-Lite metadata
    let metadata = didl_metadata(title, media_url, mime_type, file_size);
    let escaped_metadata = xml_escape(&metadata);

    let payload = format!(
        "<InstanceID>0</InstanceID>\
         <CurrentURI>{uri}</CurrentURI>\
         <CurrentURIMetaData>{meta}</CurrentURIMetaData>",
        uri = xml_escape(media_url),
        meta = escaped_metadata,
    );

    tracing::debug!("SetAVTransportURI with metadata");
    match soap_action(control_url, &service_type, "SetAVTransportURI", &payload).await {
        Ok(_) => return Ok(()),
        Err(e) => tracing::warn!("SetAVTransportURI with metadata failed: {e}"),
    }

    // Fallback: empty metadata
    let payload = format!(
        "<InstanceID>0</InstanceID>\
         <CurrentURI>{media_url}</CurrentURI>\
         <CurrentURIMetaData></CurrentURIMetaData>",
    );

    tracing::debug!("SetAVTransportURI with empty metadata");
    soap_action(control_url, &service_type, "SetAVTransportURI", &payload)
        .await
        .map(|_| ())
}

/// Send Play action.
pub async fn play(device: &DlnaDevice, control_url: &str) -> Result<(), AppError> {
    let service_type = device.service.service_type().to_string();
    let payload = xml_payload(&[("InstanceID", "0"), ("Speed", "1")]);
    soap_action(control_url, &service_type, "Play", &payload)
        .await
        .map(|_| ())
}

/// Send Pause action.
pub async fn pause(device: &DlnaDevice, control_url: &str) -> Result<(), AppError> {
    let service_type = device.service.service_type().to_string();
    let payload = xml_payload(&[("InstanceID", "0")]);
    soap_action(control_url, &service_type, "Pause", &payload)
        .await
        .map(|_| ())
}

/// Send Stop action.
pub async fn stop(device: &DlnaDevice, control_url: &str) -> Result<(), AppError> {
    let service_type = device.service.service_type().to_string();
    let payload = xml_payload(&[("InstanceID", "0")]);
    soap_action(control_url, &service_type, "Stop", &payload)
        .await
        .map(|_| ())
}

/// Seek to an absolute position (HH:MM:SS).
pub async fn seek(device: &DlnaDevice, control_url: &str, target_secs: u64) -> Result<(), AppError> {
    let service_type = device.service.service_type().to_string();
    let h = target_secs / 3600;
    let m = (target_secs % 3600) / 60;
    let s = target_secs % 60;
    let target = format!("{h:02}:{m:02}:{s:02}");

    let payload = xml_payload(&[
        ("InstanceID", "0"),
        ("Unit", "REL_TIME"),
        ("Target", &target),
    ]);
    soap_action(control_url, &service_type, "Seek", &payload)
        .await
        .map(|_| ())
}

/// Query the device for current position info.
pub async fn get_position_info(device: &DlnaDevice, control_url: &str) -> Result<PositionInfo, AppError> {
    let service_type = device.service.service_type().to_string();
    let payload = xml_payload(&[("InstanceID", "0")]);
    let response = soap_action(control_url, &service_type, "GetPositionInfo", &payload).await?;

    let elapsed = response
        .get("RelTime")
        .map(|s| parse_duration(s))
        .unwrap_or(0);
    let duration = response
        .get("TrackDuration")
        .map(|s| parse_duration(s))
        .unwrap_or(0);

    Ok(PositionInfo {
        elapsed_secs: elapsed,
        duration_secs: duration,
    })
}

/// Query the device for transport state.
pub async fn get_transport_info(device: &DlnaDevice, control_url: &str) -> Result<PlaybackState, AppError> {
    let service_type = device.service.service_type().to_string();
    let payload = xml_payload(&[("InstanceID", "0")]);
    let response = soap_action(control_url, &service_type, "GetTransportInfo", &payload).await?;

    let state = response
        .get("CurrentTransportState")
        .map(|s| PlaybackState::from_transport_state(s))
        .unwrap_or(PlaybackState::Unknown("N/A".into()));

    Ok(state)
}
