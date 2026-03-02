@echo off
REM ================================================================
REM Безопасное обновление зависимостей Avatar Factory
REM С автоматическим backup и тестированием
REM ================================================================

setlocal enabledelayedexpansion

echo.
echo ====================================================================
echo   SAFE UPGRADE - Avatar Factory GPU Worker
echo ====================================================================
echo.
echo ВНИМАНИЕ: Это обновит следующие пакеты:
echo   - transformers: 4.36.2 -^> 4.45.0
echo   - diffusers: 0.25.1 -^> 0.30.3
echo   - accelerate: 0.25.0 -^> 0.26.1
echo   + openai-whisper (новый)
echo   + tiktoken (новый)
echo.
echo PyTorch и NumPy НЕ будут изменены (критично!)
echo.

pause

REM ================================================================
REM ШАГ 1: BACKUP
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 1/6: Создание backup venv
echo ====================================================================
echo.

REM Генерация имени backup с датой
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set backup_name=venv-backup-%datetime:~0,8%-%datetime:~8,6%

echo Создаем backup: %backup_name%
echo Это займет 2-5 минут...
echo.

if exist "%backup_name%" (
    echo ОШИБКА: Backup %backup_name% уже существует!
    echo Удалите его или подождите минуту для нового имени.
    pause
    exit /b 1
)

xcopy venv "%backup_name%" /E /I /H /Y /Q > nul

if %errorlevel% neq 0 (
    echo.
    echo ❌ ОШИБКА: Не удалось создать backup!
    pause
    exit /b 1
)

echo ✅ Backup создан: %backup_name%
echo.

REM ================================================================
REM ШАГ 2: ПРОВЕРКА ТЕКУЩЕГО СОСТОЯНИЯ
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 2/6: Проверка текущего состояния
echo ====================================================================
echo.

call venv\Scripts\activate.bat

echo Тестируем СУЩЕСТВУЮЩИЕ модели...
python test_existing_models.py

if %errorlevel% neq 0 (
    echo.
    echo ❌ ОШИБКА: Существующие модели не работают!
    echo Сначала исправьте текущие проблемы.
    pause
    exit /b 1
)

echo.
echo ✅ Все существующие модели работают
echo.

REM ================================================================
REM ШАГ 3: ОБНОВЛЕНИЕ ЗАВИСИМОСТЕЙ
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 3/6: Обновление зависимостей
echo ====================================================================
echo.

echo Обновляем пакеты из requirements-upgrade.txt...
echo Это займет 3-5 минут...
echo.

pip install --upgrade -r requirements-upgrade.txt

if %errorlevel% neq 0 (
    echo.
    echo ❌ ОШИБКА: Не удалось установить обновления!
    echo.
    echo ОТКАТЫВАЕМ к backup...
    goto :rollback
)

echo.
echo ✅ Зависимости обновлены
echo.

REM ================================================================
REM ШАГ 4: ТЕСТ СУЩЕСТВУЮЩИХ МОДЕЛЕЙ
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 4/6: Проверка существующих моделей после обновления
echo ====================================================================
echo.

echo КРИТИЧНО: Проверяем, что старые модели не сломались...
python test_existing_models.py

if %errorlevel% neq 0 (
    echo.
    echo ❌ КРИТИЧЕСКАЯ ОШИБКА: Обновления сломали существующие модели!
    echo.
    echo ОТКАТЫВАЕМ к backup...
    goto :rollback
)

echo.
echo ✅ Все существующие модели работают после обновления
echo.

REM ================================================================
REM ШАГ 5: ТЕСТ НОВЫХ МОДЕЛЕЙ
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 5/6: Проверка новых моделей
echo ====================================================================
echo.

echo Тестируем Whisper...
python -c "import whisper; model = whisper.load_model('base'); print('✅ Whisper OK')"

if %errorlevel% neq 0 (
    echo ⚠️  Whisper не работает, но существующие модели OK
    echo Можно продолжать работу или откатить для повторной попытки
    echo.
    choice /C YN /M "Откатить изменения"
    if !errorlevel! equ 1 goto :rollback
)

echo.
echo Тестируем transformers 4.45...
python -c "from transformers import AutoModelForCausalLM; print('✅ Transformers 4.45 OK')"

echo.
echo Тестируем diffusers 0.30...
python -c "from diffusers import StableDiffusionXLPipeline; print('✅ Diffusers 0.30 OK')"

echo.

REM ================================================================
REM ШАГ 6: ИТОГИ
REM ================================================================

echo.
echo ====================================================================
echo ШАГ 6/6: ИТОГИ
echo ====================================================================
echo.

echo ✅ ОБНОВЛЕНИЕ УСПЕШНО!
echo.
echo Обновленные версии:
pip show transformers diffusers accelerate openai-whisper | findstr "Name: Version:"
echo.

echo Backup сохранен в: %backup_name%
echo Вы можете удалить его через несколько дней, когда убедитесь что всё работает.
echo.

echo СЛЕДУЮЩИЕ ШАГИ:
echo 1. Перезапустите сервер: python server.py
echo 2. Протестируйте все API endpoints
echo 3. Добавьте новые endpoints (см. UPGRADE_PLAN.md)
echo.

pause
exit /b 0

REM ================================================================
REM ОТКАТ ПРИ ОШИБКАХ
REM ================================================================

:rollback
echo.
echo ====================================================================
echo   ОТКАТ К BACKUP
echo ====================================================================
echo.

echo Удаляем сломанный venv...
rmdir /S /Q venv

if %errorlevel% neq 0 (
    echo ОШИБКА: Не удалось удалить venv
    echo Удалите вручную: rmdir /S /Q venv
    pause
    exit /b 1
)

echo Восстанавливаем из backup: %backup_name%...
xcopy "%backup_name%" venv /E /I /H /Y /Q > nul

if %errorlevel% neq 0 (
    echo КРИТИЧЕСКАЯ ОШИБКА: Не удалось восстановить backup!
    echo Backup находится в: %backup_name%
    echo Восстановите вручную: xcopy %backup_name% venv /E /I /H /Y
    pause
    exit /b 1
)

echo.
echo ✅ Откат выполнен успешно
echo Вернулись к состоянию до обновления
echo.

echo Тестируем восстановленный venv...
call venv\Scripts\activate.bat
python test_existing_models.py

if %errorlevel% neq 0 (
    echo.
    echo ⚠️  ВНИМАНИЕ: После отката тесты не проходят!
    echo Возможно, проблема была и до обновления.
    echo Проверьте логи.
)

echo.
pause
exit /b 1
