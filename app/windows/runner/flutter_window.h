#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "taskbar_badge.h"
#include "tray_icon.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Start hidden in the notification area (autostart).
  void SetStartMinimized(bool minimized) { start_minimized_ = minimized; }

  // Show the window again, also when it is hidden in the notification area.
  static void Restore(HWND window);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  bool start_minimized_ = false;

  // "thask/taskbar" (lib/desktop_bridge.dart): setBadge(int), activate.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> taskbar_channel_;
  TaskbarBadge badge_;

  // Icon in the notification area; closing the window only hides it, "Quit" in its menu ends the app.
  TrayIcon tray_;
  bool quitting_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
