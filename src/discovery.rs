use std::sync::Arc;
use std::time::Duration;

use futures::StreamExt;
use rupnp::ssdp::{SearchTarget, URN};

use crate::dlna::types::DlnaDevice;
use crate::error::AppError;

const AV_TRANSPORT_URN: URN = URN::service("schemas-upnp-org", "AVTransport", 1);
const MEDIA_RENDERER_URN: URN = URN::device("schemas-upnp-org", "MediaRenderer", 1);

/// Discover DLNA MediaRenderer devices that support AVTransport:1.
/// Returns a list of devices found within the given timeout.
pub async fn discover_devices(timeout: Duration) -> Result<Vec<DlnaDevice>, AppError> {
    let search_target = SearchTarget::URN(MEDIA_RENDERER_URN);

    let devices_stream = rupnp::discover(&search_target, timeout)
        .await
        .map_err(|e| AppError::NetworkError(format!("SSDP discovery failed: {e}")))?;

    futures::pin_mut!(devices_stream);

    let mut found: Vec<DlnaDevice> = Vec::new();
    let mut seen_urls: std::collections::HashSet<String> = std::collections::HashSet::new();

    while let Some(device) = devices_stream.next().await {
        let device = match device {
            Ok(d) => d,
            Err(e) => {
                tracing::warn!("Error parsing device: {e}");
                continue;
            }
        };

        let device_url = device.url().clone();
        let url_str = device_url.to_string();

        // Skip duplicate devices (same URL seen before)
        if !seen_urls.insert(url_str) {
            continue;
        }

        // Look for AVTransport:1 service on this device
        if let Some(service) = device.find_service(&AV_TRANSPORT_URN) {
            let friendly_name = device.friendly_name().to_string();

            found.push(DlnaDevice {
                friendly_name,
                service: Arc::new(service.clone()),
                device_url,
            });
        }
    }

    Ok(found)
}
