//+------------------------------------------------------------------+
//|                                          VirtualCloseManager.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.00"

class CVirtualAdvisor;

#include "../Database/Storage.mqh"

// Возможные состояния менеджера закрытия
enum ENUM_CM_STATE {
   CM_STATE_OK,            // Лимиты не превышены (нормальное состояние)
   CM_STATE_LOSS,          // Превышен общий убыток
   CM_STATE_PROFIT,        // Достигнута общая прибыль
   CM_STATE_TRAIL_PROFIT   // Трейлинг прибыли
};

// Возможные способы расчёта общего убытка
enum ENUM_CM_CALC_LOSS {
   CM_CALC_LOSS_MONEY_BB,           // [$] Fixed Money
   CM_CALC_LOSS_PERCENT_BB,         // [%] of Base Balance
};

// Возможные способы расчёта общей прибыли
enum ENUM_CM_CALC_PROFIT {
   CM_CALC_PROFIT_MONEY_BB,           // [$] Fixed Money
   CM_CALC_PROFIT_PERCENT_BB,         // [%] of Base Balance
};

//+------------------------------------------------------------------+
//| Класс менеджера закрытия (фиксации прибыли и убытков)            |
//+------------------------------------------------------------------+
class CVirtualCloseManager : public CFactorable {
protected:
// Основные параметры конструктора
   double            m_baseBalance;          // Базовый баланс

   ENUM_CM_CALC_LOSS m_calcLossLimit;        // Способ расчёта максимального общего убытка
   double            m_maxLossLimit;         // Параметр расчёта максимального общего убытка

   ENUM_CM_CALC_PROFIT m_calcProfitLimit;    // Способ расчёта максимальной общей прибыли
   double            m_maxProfitLimit;       // Параметр расчёта максимальной общей прибыли

   CVirtualAdvisor*  m_expert;               // Указатель на объект эксперта

// Текущее состояние
   ENUM_CM_STATE     m_state;                // Состояние

// Обновляемые значения
   double            m_balance;              // Текущий баланс
   double            m_equity;               // Текущие средства
   double            m_profit;               // Текущая плавающая прибыль
   double            m_overallProfit;        // Текущая общая прибыль относительно базового баланса


// Защищённые методы
   double            LossMoney();            // Максимальный общий убыток
   double            ProfitMoney();          // Максимальная прибыль

   void              UpdateProfit();         // Обновление текущих значений прибыли
   void              CheckLimits();          // Проверка достижения допустимых уровней прибыли/убытка
  
   CVirtualCloseManager(string p_params);    // Закрытый конструктор

public:
   STATIC_CONSTRUCTOR(CVirtualCloseManager); // Статический метод создания объекта
   virtual void      Tick();                 // Обработка тика в менеджере закрытия

   virtual string    Text();                 // Информация о текущем состоянии

   // Привязка эксперта к менеджеру закрытия
   void              Expert(CVirtualAdvisor* p_expert);

   virtual bool      Save();      // Сохранение состояния
   virtual bool      Load();      // Загрузка состояния

   virtual string    operator~() override;   // Преобразование объекта в строку
};

REGISTER_FACTORABLE_CLASS(CVirtualCloseManager); // Регистрация нового потомка CFactorable

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualCloseManager::CVirtualCloseManager(string p_params) {
// Запоминаем строку инициализации
   m_params = p_params;

// Читаем строку инициализации и устанавливаем значения свойств
   m_isActive = (bool) ReadLong(p_params);
   m_baseBalance = ReadDouble(p_params);
   m_calcLossLimit = (ENUM_CM_CALC_LOSS) ReadLong(p_params);
   m_maxLossLimit = ReadDouble(p_params);
   m_calcProfitLimit = (ENUM_CM_CALC_PROFIT) ReadLong(p_params);
   m_maxProfitLimit = ReadDouble(p_params);


// Устанавливаем состояние: Лимиты не превышены
   m_state = CM_STATE_OK;

// Обновляем текущие значения прибыли
   UpdateProfit();

// Корректируем базовый баланс, если он не задан
   if(m_baseBalance == 0) {
      m_baseBalance = m_balance;
   }
}

//+------------------------------------------------------------------+
//| Обработка тика в риск-менеджере                                  |
//+------------------------------------------------------------------+
void CVirtualCloseManager::Tick() {
// Если риск-менеджер неактивен, то выходим
   if(!m_isActive) {
      return;
   }

// Обновляем текущие значения прибыли
   UpdateProfit();

// Если менеджер в состоянии трейлинга, то
   if(m_state == CM_STATE_TRAIL_PROFIT) {
      // Пока просто будем сразу фиксировать прибыль,
      // переводя менеджер в соответсвующее состояние
      if(true) {
         m_state = CM_STATE_PROFIT;
      }
   }

// Если менеджер в нормальном состоянии, то
   if(m_state == CM_STATE_OK) {
      // Проверяем превышение пределов убытка и прибыли
      CheckLimits();
   }

// Если менеджер в состоянии достигнутого убытка или прибыли, то
   if(m_state == CM_STATE_LOSS || m_state == CM_STATE_PROFIT) {
      // Закрываем все позиции
      m_expert.Close();

      // Если все позиции закрыты, то
      if(PositionsTotal() == 0) {
         // Переходим в нормальное состояние
         m_state = CM_STATE_OK;

         // Обновляем значение базового баланса
         m_baseBalance = m_balance;
      } else {
         // Ждём закрытия всех позиций
      }

      // Сохраняем состояние эксперта
      m_expert.Save();
   }
}

//+------------------------------------------------------------------+
//| Информация о текущем состоянии                                   |
//+------------------------------------------------------------------+
string CVirtualCloseManager::Text() {
   string s = "=== Close Manager ===\n";

   s += StringFormat("BL: %8.2f | Target: %8.2f (%8.2f)\n",
                     m_baseBalance,
                     m_baseBalance + ProfitMoney(),
                     m_baseBalance - LossMoney());

   return s;
}

//+------------------------------------------------------------------+
//| Привязка эксперта к менеджеру закрытия                           |
//+------------------------------------------------------------------+
void CVirtualCloseManager::Expert(CVirtualAdvisor* p_expert) {
   m_expert = p_expert;
}

//+------------------------------------------------------------------+
//| Сохранение состояния                                             |
//+------------------------------------------------------------------+
bool CVirtualCloseManager::Save() {
   CStorage::Set("CVirtualCloseManager::m_state", m_state);
   CStorage::Set("CVirtualCloseManager::m_baseBalance", m_baseBalance);

   return true;
}

//+------------------------------------------------------------------+
//| Загрузка состояния                                               |
//+------------------------------------------------------------------+
bool CVirtualCloseManager::Load() {
   bool res = true;

   res &= CStorage::Get("CVirtualCloseManager::m_state", m_state);
   res &= CStorage::Get("CVirtualCloseManager::m_baseBalance", m_baseBalance);

   return res;
}

//+------------------------------------------------------------------+
//| Максимальный общий убыток                                        |
//+------------------------------------------------------------------+
double CVirtualCloseManager::LossMoney() {
   if(m_calcLossLimit == CM_CALC_LOSS_PERCENT_BB) {
      // Для заданного процента от базового баланса вычисляем его
      return m_baseBalance * m_maxLossLimit / 100;
   } else {
      // Для фиксированного значения просто возвращаем его
      // CM_CALC_LOSS_MONEY_BB
      return m_maxLossLimit;
   }
}

//+------------------------------------------------------------------+
//| Максимальная общая прибыль                                       |
//+------------------------------------------------------------------+
double CVirtualCloseManager::ProfitMoney() {
   if(m_calcProfitLimit == CM_CALC_PROFIT_PERCENT_BB) {
      // Для заданного процента от базового баланса вычисляем его
      return m_baseBalance * m_maxProfitLimit / 100;
   } else {
      // Для фиксированного значения просто возвращаем его
      // CM_CALC_PROFIT_MONEY_BB
      return m_maxProfitLimit;
   }
}

//+------------------------------------------------------------------+
//| Обновление текущих значений прибыли                              |
//+------------------------------------------------------------------+
void CVirtualCloseManager::UpdateProfit() {
// Текущие средства
   m_equity = AccountInfoDouble(ACCOUNT_EQUITY);

// Текущий баланс
   m_balance = AccountInfoDouble(ACCOUNT_BALANCE);

// Текущая плавающая прибыль
   m_profit = m_equity - m_balance;

// Текущая общая прибыль относительно базового баланса
   m_overallProfit = m_equity - m_baseBalance;

// Раз в час выводим значения в лог
   if(IsNewBar(Symbol(), PERIOD_H1)) {
      PrintFormat(__FUNCTION__" | Profit = %.2f | Overall = %.2f",
                  m_profit, m_overallProfit);
   }
}


//+------------------------------------------------------------------+
//| Проверка лимитов убытка                                          |
//+------------------------------------------------------------------+
void CVirtualCloseManager::CheckLimits() {
// Если достигнут общий убыток
   if(m_overallProfit <= -LossMoney()) {
      // Устанавливаем риск-менеджер в состояние достигнутого общего убытка
      m_state = CM_STATE_LOSS;

      PrintFormat(__FUNCTION__" | CLOSE LOSS Profit = %.2f | OverallProfit = %.2f (%.2f)",
                  m_profit, m_overallProfit, -LossMoney());

   }
// Если достигнут общий убыток и позиции ещё открыты
   else if(m_overallProfit >= ProfitMoney()) {
      // Устанавливаем риск-менеджер в состояние достигнутой общей прибыли
      m_state = CM_STATE_PROFIT;

      PrintFormat(__FUNCTION__" | CLOSE PROFIT Profit = %.2f | OverallProfit = %.2f (%.2f)",
                  m_profit, m_overallProfit, ProfitMoney());
   }
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CVirtualCloseManager::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}
//+------------------------------------------------------------------+
