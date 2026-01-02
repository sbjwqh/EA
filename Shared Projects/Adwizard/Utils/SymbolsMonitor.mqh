//+------------------------------------------------------------------+
//|                                               SymbolsMonitor.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.01"


#include <Trade\SymbolInfo.mqh>
#include "Macros.mqh"
#include "NewBarEvent.mqh"

//+------------------------------------------------------------------+
//| Класс получения информации о торговых инструментах (символах)    |
//+------------------------------------------------------------------+
class CSymbolsMonitor {
protected:
// Статический указатель на единственный экземпляр данного класса
   static   CSymbolsMonitor *s_instance;

// Массив информационных объектов для разных символов
   CSymbolInfo       *m_symbols[];

   string            m_symbolsNames[];

//--- Частные методы
   CSymbolsMonitor() {} // Закрытый конструктор

public:
   ~CSymbolsMonitor();   // Деструктор

//--- Статические методы
   static
   CSymbolsMonitor   *Instance();   // Синглтон - создание и получение единственного экземпляра

   // Обработка тика для объектов разных символов
   void              Tick();

   // Строка с названиями всех используемых символов
   string            SymbolsNames();

   // Оператор получения объекта с информацией о конкретном символе
   CSymbolInfo*      operator[](const string &symbol);
};

// Инициализация статического указателя на единственный экземпляр данного класса
CSymbolsMonitor *CSymbolsMonitor::s_instance = NULL;


//+------------------------------------------------------------------+
//| Синглтон - создание и получение единственного экземпляра         |
//+------------------------------------------------------------------+
CSymbolsMonitor* CSymbolsMonitor::Instance() {
   if(!s_instance) {
      s_instance = new CSymbolsMonitor();
   }
   return s_instance;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CSymbolsMonitor::~CSymbolsMonitor() {
// Удаляем все созданные информационные объекты для символов
   FOREACH(m_symbols) if(!!m_symbols[i]) delete m_symbols[i];
}

//+------------------------------------------------------------------+
//| Обработка тика для массива виртуальных ордеров (позиций)         |
//+------------------------------------------------------------------+
void CSymbolsMonitor::Tick() {
// Обновляем котировки каждую минуту и спецификацию раз в день
   FOREACH(m_symbols) {
      if(IsNewBar(m_symbols[i].Name(), PERIOD_D1)) {
         m_symbols[i].Refresh();
      }
      if(IsNewBar(m_symbols[i].Name(), PERIOD_M1)) {
         m_symbols[i].RefreshRates();
      }
   }
}

//+------------------------------------------------------------------+
//| Строка с названиями всех используемых символов                   |
//+------------------------------------------------------------------+
string CSymbolsMonitor::SymbolsNames() {
   string names = "";
   
   JOIN(m_symbolsNames, names, ", ");
   
   return names;
}

//+------------------------------------------------------------------+
//| Оператор получения объекта с информацией о конкретном символе    |
//+------------------------------------------------------------------+
CSymbolInfo* CSymbolsMonitor::operator[](const string &name) {
// Ищем информационный объект для данного символа в массиве
   int i;
   SEARCH(m_symbols, m_symbols[i].Name() == name, i);

// Если нашли, то возвращаем его
   if(i != -1) {
      return m_symbols[i];
   } else if (name != "") {
      // Иначе создаём новый информационный объект
      CSymbolInfo *s = new CSymbolInfo();
      // Выбираем для него нужный символ
      if(s.Name(name)) {
         // Если выбрали успешно, то обновляем спецификацию
         s.RefreshRates();
         // Добавляем в массив информационных объектов и возвращаем его
         APPEND(m_symbols, s);

         APPEND(m_symbolsNames, name);

         // Регистрируем обработчик события нового бара на минимальном таймфрейме
         IsNewBar(name, PERIOD_M1);
         return s;
      } else {
         PrintFormat(__FUNCTION__" | ERROR: can't create symbol with name [%s]", name);
         delete s;
      }
   }
   return NULL;
}
//+------------------------------------------------------------------+
