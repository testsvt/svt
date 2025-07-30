#!/usr/bin/env python3
import pandas as pd
import os
import re

def contains_chinese(text):
    """Проверить, содержит ли текст китайские символы"""
    if pd.isna(text) or not isinstance(text, str):
        return False
    chinese_pattern = re.compile(r'[\u4e00-\u9fff]')
    return bool(chinese_pattern.search(text))

def check_file_content(file_path, column_name):
    """Проверить содержимое файла"""
    try:
        df = pd.read_excel(file_path, engine='openpyxl')
        print(f"  📊 Файл: {os.path.basename(file_path)}")
        print(f"  📊 Размер: {len(df)} строк, {len(df.columns)} столбцов")
        
        if column_name in df.columns:
            print(f"  📊 Столбец {column_name}:")
            
            # Показываем первые 10 значений
            chinese_count = 0
            russian_count = 0
            
            for i, value in enumerate(df[column_name].head(10)):
                if pd.notna(value):
                    if contains_chinese(str(value)):
                        print(f"    {i}: {value} (китайский)")
                        chinese_count += 1
                    else:
                        print(f"    {i}: {value} (русский/другой)")
                        russian_count += 1
            
            # Подсчитываем общее количество китайских и русских значений
            total_chinese = 0
            total_russian = 0
            
            for value in df[column_name]:
                if pd.notna(value):
                    if contains_chinese(str(value)):
                        total_chinese += 1
                    else:
                        total_russian += 1
            
            print(f"  📊 Статистика столбца {column_name}:")
            print(f"    Китайских значений: {total_chinese}")
            print(f"    Русских/других значений: {total_russian}")
        else:
            print(f"  ❌ Столбец {column_name} не найден")
            print(f"  📋 Доступные столбцы: {list(df.columns)}")
        
        print()
        
    except Exception as e:
        print(f"  ❌ Ошибка при чтении файла: {e}")

def main():
    print("🔍 Проверяю восстановленные файлы...")
    print("="*60)
    
    source_dir = "Character.edf_ru"
    target_dir = "Character.edf_main"
    
    # Проверяем файлы
    files_to_check = [
        {
            'source_file': os.path.join(source_dir, "Grade.xlsx"),
            'target_file': os.path.join(target_dir, "Grade.xlsx"),
            'column': 'string[32]'
        },
        {
            'source_file': os.path.join(source_dir, "MonsterCharacter.xlsx"),
            'target_file': os.path.join(target_dir, "MonsterCharacter.xlsx"),
            'column': 'string[64].1'
        },
        {
            'source_file': os.path.join(source_dir, "Class.xlsx"),
            'target_file': os.path.join(target_dir, "Class.xlsx"),
            'column': 'string[64].10'
        },
        {
            'source_file': os.path.join(source_dir, "Action.xlsx"),
            'target_file': os.path.join(target_dir, "Action.xlsx"),
            'column': 'string[32]'
        }
    ]
    
    for file_config in files_to_check:
        source_file = file_config['source_file']
        target_file = file_config['target_file']
        column = file_config['column']
        
        print(f"\n📁 Проверяю файл: {os.path.basename(target_file)}")
        print(f"   Столбец: {column}")
        
        if os.path.exists(source_file):
            print(f"  📂 Исходный файл (Character.edf_ru) - русский:")
            check_file_content(source_file, column)
        
        if os.path.exists(target_file):
            print(f"  📂 Целевой файл (Character.edf_main) - должен быть китайский:")
            check_file_content(target_file, column)
        else:
            print(f"  ❌ Целевой файл не найден!")

if __name__ == "__main__":
    main()