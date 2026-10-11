# Check report

Run at 2026-10-11 17:12 UTC.

| Step | Result |
|---|---|
| Spec | passed |
| Flutter project | passed |
| Design and icons | passed |
| Build and widget tests | passed |
| Acceptance coverage and emulator tests | FAILED (1) |
| Store text | not run (an earlier step failed) |
| Screenshots and store images | not run (an earlier step failed) |
| Release bundle and APK | not run (an earlier step failed) |

## Acceptance coverage and emulator tests

```
 a restart                                                                                                         
00:39 +0 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test (but after the test had completed):
A AppState was used after being disposed.
Once you have called dispose() on a AppState, it can no longer be used.

When the exception was thrown, this was the stack:
#0      ChangeNotifier.debugAssertNotDisposed.<anonymous closure> (package:flutter/src/foundation/change_notifier.dart:184:9)
#1      ChangeNotifier.debugAssertNotDisposed (package:flutter/src/foundation/change_notifier.dart:191:6)
#2      ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:414:27)
#3      AppState.load (package:trippi/state/app_state.dart:113:5)
<asynchronous suspension>
════════════════════════════════════════════════════════════════════════════════════════════════════

00:39 +0 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart [E]                                                                                  
  Test failed. See exception logs above.
  The test description was: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart
  

00:44 +1 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:44 +1 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:45 +1 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:45 +2 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:45 +2 -1: (tearDownAll)                                                                                                                                                                             
00:46 +2 -1: (tearDownAll)                                                                                                                                                                             
00:47 +2 -1: (tearDownAll)                                                                                                                                                                             
00:47 +2 -1: Some tests failed.
```
