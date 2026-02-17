/// Generate DIDL-Lite XML metadata for SetAVTransportURI.
///
/// Includes DLNA protocol info flags required by many TVs (especially Xiaomi, Samsung, LG).
pub fn didl_metadata(title: &str, media_url: &str, mime_type: &str, file_size: u64) -> String {
    let title_escaped = xml_escape(title);
    let url_escaped = xml_escape(media_url);

    // DLNA.ORG_OP=01 means the server supports Range requests (byte seek)
    // DLNA.ORG_FLAGS: streaming mode flags
    let dlna_features = "DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01700000000000000000000000000000";
    let protocol_info = format!("http-get:*:{mime_type}:{dlna_features}");

    format!(
        r#"<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="-1" restricted="1"><dc:title>{title_escaped}</dc:title><upnp:class>object.item.videoItem</upnp:class><res protocolInfo="{protocol_info}" size="{file_size}">{url_escaped}</res></item></DIDL-Lite>"#
    )
}

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}
