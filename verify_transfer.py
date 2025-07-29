#!/usr/bin/env python3
import pandas as pd
import os

def verify_transfer():
    """Проверить результаты переноса данных"""
    print("Проверка результатов переноса данных...")
    print("="*60)
    
    # Проверяем несколько ключевых файлов
    files_to_check = [
        ("Grade.xlsx", "Grade_backup.xlsx"),
        ("MonsterCharacter.xlsx", "MonsterCharacter_backup.xlsx"),
        ("Class.xlsx", "Class_backup.xlsx"),
        ("Action.xlsx", "Action_backup.xlsx")
    ]
    
    for current_file, backup_file in files_to_check:
        current_path = os.path.join("Character.edf_main", current_file)
        backup_path = os.path.join("Character.edf_main", backup_file)
        
        if os.path.exists(current_path) and os.path.exists(backup_path):
            print(f"\nПроверяю файл: {current_file}")
            print("-" * 40)
            
            try:
                current_df = pd.read_excel(current_path)
                backup_df = pd.read_excel(backup_path)
                
                # Находим текстовые столбцы
                text_columns = []
                for col in current_df.columns:
                    if 'string' in col.lower():
                        sample_data = current_df[col].dropna().head(5)
                        if len(sample_data) > 0:
                            text_count = 0
                            for val in sample_data:
                                if isinstance(val, str) and len(str(val)) > 2:
                                    text_count += 1
                            if text_count >= 2:
                                text_columns.append(col)
                
                print(f"Найдено текстовых столбцов: {len(text_columns)}")
                
                # Показываем различия в первых нескольких строках
                for col in text_columns[:3]:  # Показываем только первые 3 столбца
                    print(f"\nСтолбец: {col}")
                    print("Текущие данные (первые 5 строк):")
                    for i, val in enumerate(current_df[col].head(5)):
                        print(f"  {i+1}: {val}")
                    
                    if col in backup_df.columns:
                        print("Резервные данные (первые 5 строк):")
                        for i, val in enumerate(backup_df[col].head(5)):
                            print(f"  {i+1}: {val}")
                    
                    # Проверяем, есть ли различия
                    if col in backup_df.columns:
                        current_sample = current_df[col].dropna().head(10)
                        backup_sample = backup_df[col].dropna().head(10)
                        
                        if not current_sample.equals(backup_sample):
                            print("  ✅ Данные изменились (перенос прошел успешно)")
                        else:
                            print("  ⚠️  Данные не изменились")
                    else:
                        print("  ⚠️  Столбец отсутствует в резервной копии")
                
            except Exception as e:
                print(f"Ошибка при проверке файла {current_file}: {e}")
        else:
            print(f"Файлы {current_file} или {backup_file} не найдены")

if __name__ == "__main__":
    verify_transfer()