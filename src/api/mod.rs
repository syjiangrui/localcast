pub mod handlers;
pub mod sse;
pub mod state;
pub mod types;

use std::sync::Arc;
use tokio::sync::Mutex;

use axum::routing::{get, post};
use axum::Router;
use tower_http::cors::{Any, CorsLayer};

use crate::api::state::ApiState;

pub fn api_router(state: Arc<Mutex<ApiState>>) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        .route("/api/select-file", post(handlers::select_file))
        .route("/api/discover", get(handlers::discover))
        .route("/api/select-device", post(handlers::select_device))
        .route("/api/cast", post(handlers::cast))
        .route("/api/play", post(handlers::play))
        .route("/api/pause", post(handlers::pause))
        .route("/api/stop", post(handlers::stop))
        .route("/api/seek", post(handlers::seek))
        .route("/api/status", get(handlers::status))
        .route("/api/status/stream", get(sse::status_stream))
        .layer(cors)
        .with_state(state)
}
