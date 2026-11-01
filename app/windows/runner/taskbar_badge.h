#ifndef RUNNER_TASKBAR_BADGE_H_
#define RUNNER_TASKBAR_BADGE_H_

#include <windows.h>
#include <shobjidl.h>

// A number on the taskbar button (overlay icon), like the badge of MS To Do.
class TaskbarBadge {
 public:
  TaskbarBadge();
  ~TaskbarBadge();

  void Attach(HWND window);

  // Shows |count| on the taskbar button; 0 removes the badge.
  void Set(int count);

  // Call for the message "TaskbarButtonCreated": Explorer forgets the
  // overlay when the button is (re)created, e.g. after an Explorer restart.
  void OnButtonCreated();

  static UINT ButtonCreatedMessage();

 private:
  HICON CreateIcon(int count) const;
  void Apply();

  HWND window_ = nullptr;
  ITaskbarList3* taskbar_ = nullptr;
  ULONG_PTR gdiplus_token_ = 0;
  int count_ = 0;
};

#endif  // RUNNER_TASKBAR_BADGE_H_
