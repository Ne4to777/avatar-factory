"""
Проверка совместимости новых зависимостей с текущим стеком
Запускать ПЕРЕД установкой новых пакетов!
"""

import sys
import subprocess
import json
from pathlib import Path
import importlib.metadata

def parse_version(ver_str):
    """Простой парсер версий (major.minor.patch)"""
    return tuple(map(int, ver_str.split('.')[:3]))

print("=" * 70)
print("🔍 COMPATIBILITY CHECK - Avatar Factory GPU Worker")
print("=" * 70)

# === Текущий стек (критичные версии) ===
CURRENT_STACK = {
    "torch": "2.1.0",
    "transformers": "4.36.2",
    "diffusers": "0.25.1",
    "numpy": "1.26.4",
    "opencv-python": "4.9.0",
    "accelerate": "0.25.0",
}

# === Требования новых моделей ===
NEW_MODELS_REQUIREMENTS = {
    "Whisper Large V3": {
        "transformers": ">=4.35.0",
        "torch": ">=2.0.0",
        "numpy": ">=1.20.0,<2.0.0",
    },
    "Llama 3.3 8B": {
        "transformers": ">=4.43.0",  # КОНФЛИКТ!
        "torch": ">=2.0.0",
        "accelerate": ">=0.26.0",
    },
    "Llama 3.3 70B": {
        "transformers": ">=4.43.0",  # КОНФЛИКТ!
        "torch": ">=2.0.0",
        "accelerate": ">=0.26.0",
    },
    "AnimateDiff": {
        "diffusers": ">=0.27.0",  # КОНФЛИКТ!
        "transformers": ">=4.40.0",
        "torch": ">=2.0.0",
    },
    "Stable Video Diffusion": {
        "diffusers": ">=0.25.0",  # ОК
        "transformers": ">=4.35.0",  # ОК
        "torch": ">=2.0.0",
    },
}

# === Безопасные альтернативы (без апгрейда) ===
SAFE_ALTERNATIVES = {
    "Llama 2 7B": {
        "transformers": ">=4.30.0",  # ОК
        "torch": ">=2.0.0",
    },
    "Mistral 7B v0.1": {
        "transformers": ">=4.34.0",  # ОК
        "torch": ">=2.0.0",
    },
    "Phi-2": {
        "transformers": ">=4.37.0",  # Небольшой апгрейд
        "torch": ">=2.0.0",
    },
}


def get_installed_version(package_name):
    """Получить установленную версию пакета"""
    try:
        return importlib.metadata.version(package_name)
    except importlib.metadata.PackageNotFoundError:
        return None


def compare_versions(current, required):
    """
    Сравнить версии
    required может быть: ">=4.35.0", ">=4.35.0,<5.0.0"
    """
    if not current:
        return False, "не установлен"
    
    try:
        current_tuple = parse_version(current)
    except:
        return False, f"не удалось распарсить {current}"
    
    # Парсим требование
    requirements = required.split(",")
    
    for req in requirements:
        req = req.strip()
        
        try:
            if req.startswith(">="):
                min_ver = req[2:]
                if current_tuple < parse_version(min_ver):
                    return False, f"{current} < {min_ver}"
            elif req.startswith("<="):
                max_ver = req[2:]
                if current_tuple > parse_version(max_ver):
                    return False, f"{current} > {max_ver}"
            elif req.startswith("<"):
                max_ver = req[1:]
                if current_tuple >= parse_version(max_ver):
                    return False, f"{current} >= {max_ver}"
            elif req.startswith(">"):
                min_ver = req[1:]
                if current_tuple <= parse_version(min_ver):
                    return False, f"{current} <= {min_ver}"
            elif req.startswith("=="):
                exact_ver = req[2:]
                if current_tuple != parse_version(exact_ver):
                    return False, f"{current} != {exact_ver}"
        except Exception as e:
            return False, f"ошибка сравнения: {e}"
    
    return True, "ОК"


def check_model_compatibility(model_name, requirements):
    """Проверить совместимость модели с текущим стеком"""
    print(f"\n{'─' * 70}")
    print(f"📦 {model_name}")
    print(f"{'─' * 70}")
    
    conflicts = []
    compatible = True
    
    for package, required_version in requirements.items():
        current_version = get_installed_version(package)
        is_ok, reason = compare_versions(current_version, required_version)
        
        status = "✅" if is_ok else "❌"
        print(f"{status} {package:20s}: {current_version or 'не установлен':15s} (требует: {required_version})")
        
        if not is_ok:
            compatible = False
            conflicts.append({
                "package": package,
                "current": current_version,
                "required": required_version,
                "reason": reason
            })
    
    return compatible, conflicts


def main():
    print("\n" + "=" * 70)
    print("1️⃣  ТЕКУЩИЙ СТЕК")
    print("=" * 70)
    
    for package, expected_version in CURRENT_STACK.items():
        installed = get_installed_version(package)
        status = "✅" if installed == expected_version else "⚠️"
        print(f"{status} {package:20s}: {installed or 'не установлен'} (ожидалось: {expected_version})")
    
    # Проверка новых моделей
    print("\n" + "=" * 70)
    print("2️⃣  НОВЫЕ МОДЕЛИ (проверка совместимости)")
    print("=" * 70)
    
    results = {}
    
    for model_name, requirements in NEW_MODELS_REQUIREMENTS.items():
        compatible, conflicts = check_model_compatibility(model_name, requirements)
        results[model_name] = {
            "compatible": compatible,
            "conflicts": conflicts
        }
    
    # Безопасные альтернативы
    print("\n" + "=" * 70)
    print("3️⃣  БЕЗОПАСНЫЕ АЛЬТЕРНАТИВЫ (без апгрейда)")
    print("=" * 70)
    
    safe_results = {}
    
    for model_name, requirements in SAFE_ALTERNATIVES.items():
        compatible, conflicts = check_model_compatibility(model_name, requirements)
        safe_results[model_name] = {
            "compatible": compatible,
            "conflicts": conflicts
        }
    
    # Итоговый отчет
    print("\n" + "=" * 70)
    print("📊 ИТОГОВЫЙ ОТЧЕТ")
    print("=" * 70)
    
    print("\n✅ Модели, готовые к установке БЕЗ апгрейда:")
    safe_models = [name for name, res in results.items() if res["compatible"]]
    if safe_models:
        for model in safe_models:
            print(f"   • {model}")
    else:
        print("   (нет)")
    
    print("\n❌ Модели, требующие апгрейда зависимостей:")
    unsafe_models = [name for name, res in results.items() if not res["compatible"]]
    if unsafe_models:
        for model in unsafe_models:
            print(f"   • {model}")
            for conflict in results[model]["conflicts"]:
                print(f"      - {conflict['package']}: {conflict['reason']}")
    
    print("\n🟢 Безопасные альтернативы (работают с текущим стеком):")
    working_alternatives = [name for name, res in safe_results.items() if res["compatible"]]
    if working_alternatives:
        for model in working_alternatives:
            print(f"   • {model}")
    else:
        print("   (нет)")
    
    # Рекомендации
    print("\n" + "=" * 70)
    print("💡 РЕКОМЕНДАЦИИ")
    print("=" * 70)
    
    if len(safe_models) > 0:
        print("\n✅ ПУТЬ 1: Безопасное добавление (БЕЗ рисков)")
        print("   Можно установить:")
        for model in safe_models:
            print(f"   • {model}")
        print("\n   Команда:")
        if "Whisper Large V3" in safe_models:
            print("   pip install openai-whisper")
        if "Stable Video Diffusion" in safe_models:
            print("   # SVD уже включен в diffusers 0.25.1")
    
    if len(working_alternatives) > 0:
        print("\n🟡 ПУТЬ 2: Использовать альтернативы")
        print("   Вместо Llama 3.3 использовать:")
        for model in working_alternatives:
            print(f"   • {model}")
        print("\n   Установка (пример Mistral 7B):")
        print("   # Уже работает с transformers 4.36.2")
        print("   # Загрузка: AutoModelForCausalLM.from_pretrained('mistralai/Mistral-7B-v0.1')")
    
    if len(unsafe_models) > 0:
        print("\n⚠️  ПУТЬ 3: Апгрейд (ТЕСТИРОВАТЬ В ОТДЕЛЬНОМ VENV!)")
        print("   1. Создать тестовый venv:")
        print("      python -m venv test-upgrade-venv")
        print("      test-upgrade-venv\\Scripts\\activate")
        print("\n   2. Установить апгрейды:")
        print("      pip install torch==2.1.0 torchvision==0.16.0 --index-url https://download.pytorch.org/whl/cu118")
        print("      pip install transformers==4.43.0 diffusers==0.30.0 accelerate==0.26.0")
        print("\n   3. Протестировать ВСЕ существующие модели:")
        print("      python test_existing_models.py")
        print("\n   4. Если всё работает → применить к основному venv")
        print("      Если НЕТ → остаться на текущих версиях + использовать альтернативы")
    
    print("\n" + "=" * 70)
    print("⚠️  ВАЖНО: НЕ ОБНОВЛЯЙТЕ ЗАВИСИМОСТИ БЕЗ ТЕСТИРОВАНИЯ!")
    print("=" * 70)
    
    # Сохранение отчета
    report = {
        "current_stack": CURRENT_STACK,
        "new_models": results,
        "safe_alternatives": safe_results,
        "safe_to_install": safe_models,
        "requires_upgrade": unsafe_models,
    }
    
    report_path = Path("compatibility_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\n📄 Отчет сохранен: {report_path}")
    
    return len(unsafe_models) == 0  # True если все модели совместимы


if __name__ == "__main__":
    try:
        all_compatible = main()
        sys.exit(0 if all_compatible else 1)
    except Exception as e:
        print(f"\n❌ ОШИБКА: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
