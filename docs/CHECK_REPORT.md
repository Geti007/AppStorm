# Check report

Run at 2026-10-11 18:13 UTC.

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
                                    
00:31 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:32 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:33 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:34 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:35 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:36 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:37 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:38 +1 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:38 +2 -1: AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart                                                                                      
00:38 +2 -1: (tearDownAll)                                                                                                                                                                             
00:38 +2 -1: (tearDownAll)                                                                                                                                                                             
FAILED: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart
The finder "Found 0 widgets with text "Lisbon weekend": []" (used in a call to "tap()") could not find any matching widgets.
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2095:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/AppStorm/AppStorm/app/integration_test/app_test.dart:115:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)

00:39 +2 -1: Some tests failed.
```
