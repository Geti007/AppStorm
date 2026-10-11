# Check report

Run at 2026-10-11 19:31 UTC.

| Step | Result |
|---|---|
| Spec | passed |
| Flutter project | passed |
| Design and icons | passed |
| Build and widget tests | passed |
| Acceptance coverage and emulator tests | passed |
| Store text | passed |
| Screenshots and store images | FAILED (1) |
| Release bundle and APK | not run (an earlier step failed) |

## Screenshots and store images

```
nymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
I/flutter ( 6472): <asynchronous suspension>
I/flutter ( 6472): #6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
I/flutter ( 6472): <asynchronous suspension>
I/flutter ( 6472): #7      TestWidgetsFlutterBinding._createTestCompletionHandler.<anonymous closure> (package:flutter_test/src/binding.dart:1707:12)
I/flutter ( 6472): <asynchronous suspension>
I/flutter ( 6472): 
I/flutter ( 6472): This was caught by the test expectation on the following line:
I/flutter ( 6472):   file:///home/runner/work/AppStorm/AppStorm/app/integration_test/screenshots_test.dart line 254
I/flutter ( 6472): The test description was:
I/flutter ( 6472):   store screenshots
I/flutter ( 6472): ════════════════════════════════════════════════════════════════════════════════════════════════════
I/flutter ( 6472): 00:06 +0: store screenshots [E]
I/flutter ( 6472):   Test failed. See exception logs above.
I/flutter ( 6472):   The test description was: store screenshots
I/flutter ( 6472):   
I/flutter ( 6472): 00:06 +0 -1: (tearDownAll)
D/EGL_emulation( 6472): app_time_stats: avg=1953.16ms min=1953.16ms max=1953.16ms count=1
I/flutter ( 6472): 00:06 +1 -1: Some tests failed.
Failure Details:
Failure in method: store screenshots
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═════════════════
The following TestFailure was thrown running a test:
Expected: a value greater than or equal to <107.80952380952381>
  Actual: <107.8095238095238>
   Which: is not a value greater than or equal to
<107.80952380952381>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/AppStorm/AppStorm/app/integration_test/screenshots_test.dart:254:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
#7      TestWidgetsFlutterBinding._createTestCompletionHandler.<anonymous closure> (package:flutter_test/src/binding.dart:1707:12)
<asynchronous suspension>

This was caught by the test expectation on the following line:
  file:///home/runner/work/AppStorm/AppStorm/app/integration_test/screenshots_test.dart line 254
The test description was:
  store screenshots
═════════════════════════════════════════════════════════════════

end of failure 1




VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:38405/elqe4caajNA=/
VMServiceFlutterDriver: Isolate found with number: 4903106957663487
VMServiceFlutterDriver: Isolate 4903106957663487 is runnable.
VMServiceFlutterDriver: Isolate is paused at start.
VMServiceFlutterDriver: Attempting to resume isolate
VMServiceFlutterDriver: Connected to Flutter application.
VMServiceFlutterDriver: request_data message is taking a long time to complete...
```
