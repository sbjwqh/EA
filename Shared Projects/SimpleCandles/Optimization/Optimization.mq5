//+------------------------------------------------------------------+
//|                                                 Optimization.mq5 |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property description "Советник для автоматической оптимизации проектов"

#property version "1.03"

// Константы с параметрами по умолчанию для проекта:
// - Файл с основной базой данных
#define OPT_FILEMNAME "article.17607.db.sqlite"

// - Путь к интерпретатору Python
#define OPT_PYTHONPATH "E:\\python\\python.exe"

#include "../../Adwizard/Experts/Optimization.mqh"