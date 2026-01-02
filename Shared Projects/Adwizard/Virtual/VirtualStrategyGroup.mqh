//+------------------------------------------------------------------+
//|                                         VirtualStrategyGroup.mqh |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.04"

#include "VirtualStrategy.mqh"

//+------------------------------------------------------------------+
//| Класс группы торговых стратегий или групп торговых стратегий     |
//+------------------------------------------------------------------+
class CVirtualStrategyGroup : public CFactorable {
protected:
   double            m_scale;                // Коэффициент масштабирования
   void              Scale(double p_scale);  // Масштабирование нормированного баланса

                     CVirtualStrategyGroup(string p_params); // Конструктор
public:
                     STATIC_CONSTRUCTOR(CVirtualStrategyGroup);
   virtual string    operator~() override;      // Преобразование объекта в строку

   CVirtualStrategy      *m_strategies[];       // Массив стратегий
   CVirtualStrategyGroup *m_groups[];           // Массив групп стратегий

   string            ToStringNorm(double p_scale);
};

REGISTER_FACTORABLE_CLASS(CVirtualStrategyGroup);

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualStrategyGroup::CVirtualStrategyGroup(string p_params) {
// Запоминаем строку инициализации
   m_params = p_params;

// Читаем строку инициализации массива стратегий или групп
   string items = ReadArrayString(p_params);

// Пока строка не опустела
   while(items != NULL) {
      // Читаем строку инициализации одного объекта стратегии или группы
      string itemParams = ReadObject(items);

      // Если это группа стратегий, то
      if(IsObjectOf(itemParams, "CVirtualStrategyGroup")) {
         // Создаём группу стратегий и добавляем её в массив групп
         CREATE(CVirtualStrategyGroup, group, itemParams);
         if(group.IsActive()) {
            APPEND(m_groups, group);
         } else {
            PrintFormat(__FUNCTION__" | Group is INACTIVE for Params:\n%s", itemParams);
         }
      } else {
         // Иначе создаём стратегию и добавляем её в массив стратегий
         CREATE(CVirtualStrategy, strategy, itemParams);
         if(strategy.IsActive()) {
            APPEND(m_strategies, strategy);
         } else {
            PrintFormat(__FUNCTION__" | Strategy is INACTIVE for Params:\n%s", itemParams);
         }
      }
   }

// Читаем масштабирующий множитель
   m_scale = ReadDouble(p_params);

// Исправляем его при необходимости
   if(m_scale <= 0.0) {
      m_scale = 1.0;
   }

   if(ArraySize(m_groups) > 0 && ArraySize(m_strategies) == 0) {
      // Если мы наполнили массив групп, а массив стратегий пустой, то
      PrintFormat(__FUNCTION__" | Scale = %.2f, total groups = %d", m_scale, ArraySize(m_groups));
      // Масштабируем все группы
      Scale(m_scale / ArraySize(m_groups));
   } else if(ArraySize(m_strategies) > 0 && ArraySize(m_groups) == 0) {
      // Если мы наполнили массив стратегий, а массив групп пустой, то
      PrintFormat(__FUNCTION__" | Scale = %.2f, total strategies = %d", m_scale, ArraySize(m_strategies));
      // Масштабируем все стратегии
      Scale(m_scale / ArraySize(m_strategies));
   } else {
      // Иначе сообщаем об ошибке в строке инициализации
      //SetInvalid(__FUNCTION__, StringFormat("Groups or strategies not found in Params:\n%s", p_params));
      //PrintFormat(__FUNCTION__" | Groups or strategies not found in Params:\n%s", p_params);
      m_isActive = false;
   }
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CVirtualStrategyGroup::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку с нормировкой                    |
//+------------------------------------------------------------------+
string CVirtualStrategyGroup::ToStringNorm(double p_scale) {
   return StringFormat("%s([%s],%f)", typename(this), ReadArrayString(m_params), p_scale);
}

//+------------------------------------------------------------------+
//| Масштабирование нормированного баланса                           |
//+------------------------------------------------------------------+
void CVirtualStrategyGroup::Scale(double p_scale) {
//int totalGroups = ArraySize(m_groups);
//int totalStrategies = ArraySize(m_strategies);
//int total = totalGroups + totalStrategies;
//PrintFormat(__FUNCTION__" | Scale = %.4f, total groups = %d, total strategies = %d, total = %d", p_scale, totalGroups, totalStrategies, total);
   FOREACH(m_groups)     m_groups[i].Scale(p_scale);
   FOREACH(m_strategies) m_strategies[i].Scale(p_scale);
}
//+------------------------------------------------------------------+
