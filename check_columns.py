#!/usr/bin/env python3
import pandas as pd
import os
import glob

def check_file_structure(filepath):
    """Проверить структуру файла и найти столбцы с названиями и описаниями"""
    print(f"\n{'='*60}")
    print(f"Файл: {os.path.basename(filepath)}")
    print(f"{'='*60}")
    
    try:
        df = pd.read_excel(filepath)
        print(f"Размер: {len(df)} строк, {len(df.columns)} столбцов")
        print(f"\nВсе столбцы:")
        
        for i, col in enumerate(df.columns):
            print(f"  {i+1:2d}. {col}")
        
        print(f"\nПервые 3 строки данных:")
        print(df.head(3).to_string())
        
        # Поиск столбцов, которые могут содержать названия или описания
        print(f"\nПоиск столбцов с названиями и описаниями:")
        
        # Проверяем каждый столбец на наличие текстовых данных
        text_columns = []
        for col in df.columns:
            # Берем первые 10 непустых значений
            sample_data = df[col].dropna().head(10)
            if len(sample_data) > 0:
                # Проверяем, содержит ли столбец текстовые данные
                text_count = 0
                for val in sample_data:
                    if isinstance(val, str) and len(str(val)) > 3:
                        text_count += 1
                
                if text_count >= 3:  # Если хотя бы 3 из 10 значений - текст
                    text_columns.append(col)
                    print(f"  Возможный текстовый столбец: {col}")
                    print(f"    Примеры: {sample_data.head(3).tolist()}")
        
        return text_columns
        
    except Exception as e:
        print(f"Ошибка при чтении файла: {e}")
        return []

def main():
    source_dir = "Character.edf_ru"
    
    if not os.path.exists(source_dir):
        print(f"❌ Папка {source_dir} не найдена!")
        return
    
    # Получаем список всех Excel файлов
    source_files = glob.glob(os.path.join(source_dir, "*.xlsx"))
    
    if not source_files:
        print(f"❌ В папке {source_dir} не найдено Excel файлов!")
        return
    
    print(f"Найдено {len(source_files)} файлов для анализа:")
    for file in source_files:
        print(f"  - {os.path.basename(file)}")
    
    print("\nНачинаю анализ структуры файлов...")
    
    for source_file in source_files:
        check_file_structure(source_file)

if __name__ == "__main__":
    main()