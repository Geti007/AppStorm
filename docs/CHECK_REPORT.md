# Check report

Run at 2026-10-11 17:28 UTC.

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
m/AppStorm/app/integration_test/app_test.dart -p vm --plain-name 'AC-50 AC-2 AC-9 AC-22 AC-48 a new user creates a trip, adds expenses and the data survives a restart'

00:34 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:35 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:36 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:37 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:38 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:39 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:40 +0 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:40 +1 -1: AC-24 AC-26 AC-48 settling up is saved and the trip stays settled after a restart                                                                                                         
00:40 +1 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:41 +1 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:41 +2 -1: AC-36 AC-46 Premium is re-checked with the store at launch and removes ads                                                                                                                
00:41 +2 -1: (tearDownAll)                                                                                                                                                                             
00:42 +2 -1: (tearDownAll)                                                                                                                                                                             
00:43 +2 -1: (tearDownAll)                                                                                                                                                                             
00:43 +2 -1: Some tests failed.
```
