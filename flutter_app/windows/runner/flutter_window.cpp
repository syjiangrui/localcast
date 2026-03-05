#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  StopBackend();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  StartBackend();

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Register MethodChannel for Dart to query the backend port.
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.localcast/backend",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getPort") {
          result->Success(flutter::EncodableValue(static_cast<int>(backend_port_)));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  StopBackend();

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::StartBackend() {
  // Locate the directory containing the running executable.
  wchar_t exe_path[MAX_PATH];
  DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    OutputDebugStringW(L"LocalCast: failed to get exe path\n");
    return;
  }

  // Strip the executable filename to get the directory.
  std::wstring exe_dir(exe_path);
  size_t last_sep = exe_dir.find_last_of(L'\\');
  if (last_sep != std::wstring::npos) {
    exe_dir = exe_dir.substr(0, last_sep);
  }

  // 1. Production: localcast.exe sits next to the Flutter executable.
  std::wstring backend_path = exe_dir + L"\\localcast.exe";

  if (GetFileAttributesW(backend_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    // 2. Development: walk up directories to find target\release\localcast.exe
    //    (mirrors the macOS AppDelegate approach).
    std::wstring search_dir = exe_dir;
    for (int i = 0; i < 10; ++i) {
      size_t sep = search_dir.find_last_of(L'\\');
      if (sep == std::wstring::npos) break;
      search_dir = search_dir.substr(0, sep);

      std::wstring cargo_toml = search_dir + L"\\Cargo.toml";
      if (GetFileAttributesW(cargo_toml.c_str()) != INVALID_FILE_ATTRIBUTES) {
        // Found the project root. Try release first, then debug.
        std::wstring release = search_dir + L"\\target\\release\\localcast.exe";
        std::wstring debug = search_dir + L"\\target\\debug\\localcast.exe";
        if (GetFileAttributesW(release.c_str()) != INVALID_FILE_ATTRIBUTES) {
          backend_path = release;
        } else if (GetFileAttributesW(debug.c_str()) != INVALID_FILE_ATTRIBUTES) {
          backend_path = debug;
        }
        break;
      }
    }
  }

  if (GetFileAttributesW(backend_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    OutputDebugStringW(L"LocalCast: backend binary not found\n");
    return;
  }

  // Build command line: "path\to\localcast.exe" --api --api-port 0
  std::wstring cmd_line = L"\"" + backend_path + L"\" --api --api-port 0";

  // Create a pipe to capture stdout so we can read the actual port.
  HANDLE stdout_read = nullptr;
  HANDLE stdout_write = nullptr;
  SECURITY_ATTRIBUTES sa = {};
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;

  if (!CreatePipe(&stdout_read, &stdout_write, &sa, 0)) {
    OutputDebugStringW(L"LocalCast: failed to create stdout pipe\n");
    return;
  }
  // Ensure the read end is not inherited by the child.
  SetHandleInformation(stdout_read, HANDLE_FLAG_INHERIT, 0);

  STARTUPINFOW si = {};
  si.cb = sizeof(si);
  si.hStdOutput = stdout_write;
  si.dwFlags |= STARTF_USESTDHANDLES;
  PROCESS_INFORMATION pi = {};

  BOOL ok = CreateProcessW(
      backend_path.c_str(),   // Application name
      &cmd_line[0],           // Command line (mutable)
      nullptr,                // Process security attributes
      nullptr,                // Thread security attributes
      TRUE,                   // Inherit handles (for stdout pipe)
      CREATE_NO_WINDOW,       // Creation flags - no console window
      nullptr,                // Environment
      nullptr,                // Current directory
      &si,                    // Startup info
      &pi                     // Process information
  );

  // Close write end in parent so ReadFile will see EOF when child closes it.
  CloseHandle(stdout_write);

  if (ok) {
    backend_process_ = pi.hProcess;
    backend_thread_ = pi.hThread;

    // Read stdout to find "LOCALCAST_PORT=<port>".
    char buf[256] = {};
    DWORD bytes_read = 0;
    if (ReadFile(stdout_read, buf, sizeof(buf) - 1, &bytes_read, nullptr) && bytes_read > 0) {
      std::string output(buf, bytes_read);
      auto pos = output.find("LOCALCAST_PORT=");
      if (pos != std::string::npos) {
        auto port_str = output.substr(pos + 15);
        // Trim trailing whitespace/newline
        auto end = port_str.find_first_of("\r\n ");
        if (end != std::string::npos) port_str = port_str.substr(0, end);
        int port = std::stoi(port_str);
        if (port > 0 && port <= 65535) {
          backend_port_ = static_cast<uint16_t>(port);
        }
      }
    }

    CloseHandle(stdout_read);
    OutputDebugStringW((L"LocalCast: backend started on port " + std::to_wstring(backend_port_) + L"\n").c_str());
  } else {
    CloseHandle(stdout_read);
    OutputDebugStringW(L"LocalCast: failed to start backend\n");
  }
}

void FlutterWindow::StopBackend() {
  if (backend_process_) {
    TerminateProcess(backend_process_, 0);
    WaitForSingleObject(backend_process_, 5000);
    CloseHandle(backend_process_);
    backend_process_ = nullptr;
  }
  if (backend_thread_) {
    CloseHandle(backend_thread_);
    backend_thread_ = nullptr;
  }
}
