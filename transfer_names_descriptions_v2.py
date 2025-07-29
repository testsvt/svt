#!/usr/bin/env python3
import pandas as pd
import os
import glob
from pathlib import Path

def find_name_description_columns(df):
    """Найти столбцы с названиями и описаниями"""
    name_columns = []
    description_columns = []
    
    for col in df.columns:
        col_lower = col.lower()
        # Поиск столбцов с названиями
        if any(keyword in col_lower for keyword in ['name', 'title', 'название', 'имя']):
            name_columns.append(col)
        # Поиск столбцов с описаниями
        elif any(keyword in col_lower for keyword in ['desc', 'description', 'описание', 'текст']):
            description_columns.append(col)
    
    # Если не найдены стандартные названия, ищем по типу данных и содержимому
    if not name_columns:
        for col in df.columns:
            if 'string' in col.lower():
                # Проверяем содержимое столбца
                sample_data = df[col].dropna().head(10)
                if len(sample_data) > 0:
                    # Проверяем, содержит ли столбец текстовые данные
                    text_count = 0
                    for val in sample_data:
                        if isinstance(val, str) and len(str(val)) > 2:
                            text_count += 1
                    
                    if text_count >= 3:  # Если хотя бы 3 из 10 значений - текст
                        # Проверяем, не является ли это кодом или ID
                        if not any(keyword in col.lower() for keyword in ['code', 'id', 'key']):
                            name_columns.append(col)
    
    return name_columns, description_columns

def transfer_data(source_file, target_file):
    """Перенести названия и описания из исходного файла в целевой"""
    print(f"Обрабатываю: {os.path.basename(source_file)}")
    
    try:
        # Читаем файлы
        source_df = pd.read_excel(source_file)
        target_df = pd.read_excel(target_file)
        
        print(f"  Исходный файл: {len(source_df)} строк, {len(source_df.columns)} столбцов")
        print(f"  Целевой файл: {len(target_df)} строк, {len(target_df.columns)} столбцов")
        
        # Находим столбцы с названиями и описаниями
        source_name_cols, source_desc_cols = find_name_description_columns(source_df)
        target_name_cols, target_desc_cols = find_name_description_columns(target_df)
        
        print(f"  Найдены столбцы с названиями в исходном: {source_name_cols}")
        print(f"  Найдены столбцы с описаниями в исходном: {source_desc_cols}")
        print(f"  Найдены столбцы с названиями в целевом: {target_name_cols}")
        print(f"  Найдены столбцы с описаниями в целевом: {target_desc_cols}")
        
        # Ищем ключевой столбец для сопоставления (обычно ID или Code)
        key_columns = []
        for col in source_df.columns:
            if any(keyword in col.lower() for keyword in ['id', 'key', 'index', 'code']):
                if col in target_df.columns:
                    key_columns.append(col)
        
        if not key_columns:
            print("  ⚠️  Не найден ключевой столбец для сопоставления. Использую индекс.")
            # Если нет ключевого столбца, используем индекс
            min_rows = min(len(source_df), len(target_df))
            
            # Копируем названия
            for i, col in enumerate(source_name_cols):
                if i < len(target_name_cols):
                    target_df[target_name_cols[i]].iloc[:min_rows] = source_df[col].iloc[:min_rows]
                    print(f"  Перенесено название: {col} -> {target_name_cols[i]}")
            
            # Копируем описания
            for i, col in enumerate(source_desc_cols):
                if i < len(target_desc_cols):
                    target_df[target_desc_cols[i]].iloc[:min_rows] = source_df[col].iloc[:min_rows]
                    print(f"  Перенесено описание: {col} -> {target_desc_cols[i]}")
        else:
            key_col = key_columns[0]
            print(f"  Использую ключевой столбец: {key_col}")
            
            # Создаем словарь для быстрого поиска
            source_dict = source_df.set_index(key_col).to_dict('index')
            
            # Обновляем данные в целевом файле
            updated_count = 0
            for idx, row in target_df.iterrows():
                key_value = row[key_col]
                if key_value in source_dict:
                    source_data = source_dict[key_value]
                    
                    # Обновляем названия
                    for i, col in enumerate(source_name_cols):
                        if i < len(target_name_cols) and col in source_data:
                            target_df.at[idx, target_name_cols[i]] = source_data[col]
                    
                    # Обновляем описания
                    for i, col in enumerate(source_desc_cols):
                        if i < len(target_desc_cols) and col in source_data:
                            target_df.at[idx, target_desc_cols[i]] = source_data[col]
                    
                    updated_count += 1
            
            print(f"  Обновлено записей: {updated_count}")
        
        # Сохраняем результат
        backup_file = target_file.replace('.xlsx', '_backup.xlsx')
        print(f"  Создаю резервную копию: {os.path.basename(backup_file)}")
        pd.read_excel(target_file).to_excel(backup_file, index=False)
        
        print(f"  Сохраняю обновленный файл: {os.path.basename(target_file)}")
        target_df.to_excel(target_file, index=False)
        
        return True
        
    except Exception as e:
        print(f"  ❌ Ошибка при обработке файла: {e}")
        return False

def main():
    source_dir = "Character.edf_ru"
    target_dir = "Character.edf_main"
    
    if not os.path.exists(source_dir):
        print(f"❌ Папка {source_dir} не найдена!")
        return
    
    if not os.path.exists(target_dir):
        print(f"❌ Папка {target_dir} не найдена!")
        return
    
    # Получаем список всех Excel файлов в исходной папке
    source_files = glob.glob(os.path.join(source_dir, "*.xlsx"))
    
    if not source_files:
        print(f"❌ В папке {source_dir} не найдено Excel файлов!")
        return
    
    print(f"Найдено {len(source_files)} файлов для обработки:")
    for file in source_files:
        print(f"  - {os.path.basename(file)}")
    
    print("\nНачинаю перенос данных...")
    
    success_count = 0
    for source_file in source_files:
        filename = os.path.basename(source_file)
        target_file = os.path.join(target_dir, filename)
        
        if os.path.exists(target_file):
            print(f"\n{'='*50}")
            if transfer_data(source_file, target_file):
                success_count += 1
        else:
            print(f"\n⚠️  Файл {filename} не найден в целевой папке, пропускаю")
    
    print(f"\n{'='*50}")
    print(f"Обработка завершена! Успешно обработано файлов: {success_count}/{len(source_files)}")

if __name__ == "__main__":
    main()