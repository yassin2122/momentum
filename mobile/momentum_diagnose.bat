@echo off
REM Momentum diagnostics - read-only checks, writes logs to mobile\_diag\
cd /d "%~dp0"
if not exist _diag mkdir _diag
echo running... > _diag\STATUS.txt
cd ..
git status > mobile\_diag\git_status.txt 2>&1
git branch --show-current > mobile\_diag\git_branch.txt 2>&1
git log --oneline -10 >> mobile\_diag\git_branch.txt 2>&1
git remote -v >> mobile\_diag\git_branch.txt 2>&1
cd mobile
call flutter --version > _diag\flutter_version.txt 2>&1
call flutter pub get > _diag\pub_get.txt 2>&1
call flutter analyze --no-fatal-infos --no-fatal-warnings > _diag\analyze.txt 2>&1
call flutter test > _diag\test.txt 2>&1
call flutter build web --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=diag -v > _diag\build_web_verbose.txt 2>&1
echo exit %ERRORLEVEL% > _diag\build_web_exit.txt
echo done > _diag\STATUS.txt
