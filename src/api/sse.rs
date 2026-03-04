use std::convert::Infallible;
use std::sync::Arc;
use std::time::Duration;

use axum::extract::State;
use axum::response::sse::{Event, KeepAlive, Sse};
use futures::stream::Stream;
use tokio::sync::Mutex;
use tokio_stream::wrappers::BroadcastStream;
use tokio_stream::StreamExt;

use crate::api::state::ApiState;

type SharedState = Arc<Mutex<ApiState>>;
type AppState = (SharedState, tokio::sync::watch::Receiver<bool>);

/// GET /api/status/stream
/// SSE endpoint that streams status updates at ~1/sec from the poller.
pub async fn status_stream(
    State((state, _first_disc_rx)): State<AppState>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let rx = {
        let s = state.lock().await;
        s.status_tx.subscribe()
    };

    let stream = BroadcastStream::new(rx).filter_map(|result| match result {
        Ok(status) => {
            let json = serde_json::to_string(&status).unwrap_or_default();
            Some(Ok(Event::default().data(json)))
        }
        Err(_) => None,
    });

    Sse::new(stream).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keep-alive"),
    )
}

/// GET /api/devices/stream
/// SSE endpoint that pushes device list updates whenever background discovery finds changes.
pub async fn devices_stream(
    State((state, _first_disc_rx)): State<AppState>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let rx = {
        let s = state.lock().await;
        s.devices_tx.subscribe()
    };

    let stream = BroadcastStream::new(rx).filter_map(|result| match result {
        Ok(device_list) => {
            let json = serde_json::to_string(&device_list).unwrap_or_default();
            Some(Ok(Event::default().data(json)))
        }
        Err(_) => None,
    });

    Sse::new(stream).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keep-alive"),
    )
}
