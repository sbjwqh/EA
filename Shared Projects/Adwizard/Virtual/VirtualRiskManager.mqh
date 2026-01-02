//+------------------------------------------------------------------+
//|                                           VirtualRiskManager.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.06"

#include "../Database/Storage.mqh"

// Возможные состояния риск-менеджера
enum ENUM_RM_STATE {
   RM_STATE_OK,            // Лимиты не превышены
   RM_STATE_DAILY_LOSS,    // Превышен дневной лимит
   RM_STATE_RESTORE,       // Восстановление после дневного лимита
   RM_STATE_OVERALL_LOSS,  // Превышен общий лимит
   RM_STATE_OVERALL_PROFIT // Достигнута общая прибыль
};

// Возможные способы расчёта дневных лимитов
enum ENUM_RM_CALC_DAILY_LOSS {
   RM_CALC_DAILY_LOSS_MONEY_BB,    // [$] to Daily Level
   RM_CALC_DAILY_LOSS_PERCENT_BB,  // [%] from Base Balance to Daily Level
   RM_CALC_DAILY_LOSS_PERCENT_DL   // [%] from/to Daily Level
};

// Возможные способы расчёта общих лимитов
enum ENUM_RM_CALC_OVERALL_LOSS {
   RM_CALC_OVERALL_LOSS_MONEY_BB,           // [$] to Base Balance
   RM_CALC_OVERALL_LOSS_MONEY_HW_BAL,       // [$] to HW Balance
   RM_CALC_OVERALL_LOSS_MONEY_HW_EQ_BAL,    // [$] to HW Equity or Balance
   RM_CALC_OVERALL_LOSS_PERCENT_BB,         // [%] from/to Base Balance
   RM_CALC_OVERALL_LOSS_PERCENT_HW_BAL,     // [%] from/to HW Balance
   RM_CALC_OVERALL_LOSS_PERCENT_HW_EQ_BAL   // [%] from/to HW Equity or Balance
};

// Возможные способы расчёта общей прибыли
enum ENUM_RM_CALC_OVERALL_PROFIT {
   RM_CALC_OVERALL_PROFIT_MONEY_BB,           // [$] to Base Balance
   RM_CALC_OVERALL_PROFIT_PERCENT_BB,         // [%] from/to Base Balance
};

//+------------------------------------------------------------------+
//| Класс управления риском (риск-менеждер)                          |
//+------------------------------------------------------------------+
class CVirtualRiskManager : public CFactorable {
protected:
// Основные параметры конструктора
   //bool              m_isActive;             // Риск менеджер активен?

   double            m_baseBalance;          // Базовый баланс

   ENUM_RM_CALC_DAILY_LOSS   m_calcDailyLossLimit; // Способ расчёта максимального дневного убытка
   double            m_maxDailyLossLimit;          // Параметр расчёта максимального дневного убытка
   double            m_closeDailyPart;             // Значение пороговой части дневного убытка

   ENUM_RM_CALC_OVERALL_LOSS m_calcOverallLossLimit;  // Способ расчёта максимального общего убытка
   double            m_maxOverallLossLimit;           // Параметр расчёта максимального общего убытка
   double            m_closeOverallPart;              // Значение пороговой части общего убытка

   ENUM_RM_CALC_OVERALL_PROFIT m_calcOverallProfitLimit; // Способ расчёта максимальной общей прибыли
   double            m_maxOverallProfitLimit;            // Параметр расчёта максимальной общей прибыли
   datetime          m_maxOverallProfitDate;             // Предельное время для достижения общей прибыли

   double            m_maxRestoreTime;             // Время ожидания лучшего входа на просадке
   double            m_lastVirtualProfitFactor;    // Множитель начальной лучшей просадки


// Текущее состояние
   ENUM_RM_STATE     m_state;                // Состояние
   double            m_lastVirtualProfit;    // Прибыль открытых виртуальных позиций на момент лимита убытка
   datetime          m_startRestoreTime;     // Время начала восстановления размеров открытых позиций
   datetime          m_startTime;

// Обновляемые значения
   double            m_balance;              // Текущий баланс
   double            m_equity;               // Текущие средства
   double            m_profit;               // Текущая прибыль
   double            m_dailyProfit;          // Дневная прибыль
   double            m_overallProfit;        // Общая прибыль
   double            m_baseDailyBalance;     // Дневной базовый баланс
   double            m_baseDailyEquity;      // Дневные базовые средства
   double            m_baseDailyLevel;       // Дневной базовый уровень
   double            m_baseHWBalance;        // High Watermark баланса
   double            m_baseHWEquityBalance;  // High Watermark средств или баланса
   double            m_virtualProfit;        // Прибыль открытых виртуальных позиций

// Управление размером открытых позиций
   double            m_baseDepoPart;         // Используемая часть общего баланса (исходная)
   double            m_dailyDepoPart;        // Множитель используемой части общего баланса по дневному убытку
   double            m_overallDepoPart;      // Множитель используемой части общего баланса по общему убытку
   
   string            m_text;

// Защищённые методы
   double            DailyLoss();            // Максимальный дневной убыток
   double            OverallLoss();          // Максимальный общий убыток
   double            OverallProfit();        // Максимальная прибыль

   void              UpdateProfit();         // Обновление текущих значений прибыли
   void              UpdateBaseLevels();     // Обновление дневных базовых уровней

   void              CheckLimits();          // Проверка превышения допустимых убытков
   bool              CheckDailyLossLimit();     // Проверка превышения допустимого дневного убытка
   bool              CheckOverallLossLimit();   // Проверка превышения допустимого общего убытка
   bool              CheckOverallProfitLimit(); // Проверка достижения заданной прибыли

   void              CheckRestore();         // Проверка необходимости восстановления размеров открытых позиций
   bool              CheckDailyRestore();       // Проверка необходимости восстановления дневного множителя
   bool              CheckOverallRestore();     // Проверка необходимости восстановления общего множителя

   double            VirtualProfit();        // Определение прибыли открытых виртуальных позиций
   double            RestoreVirtualProfit(); // Определение прибыли открытых виртуальных позиций для восстановления

   void              SetDepoPart();          // Установка значения используемой части общего баланса

                     CVirtualRiskManager(string p_params);     // Конструктор

public:
                     STATIC_CONSTRUCTOR(CVirtualRiskManager);
   virtual void      Tick();                 // Обработка тика в риск-менеджере
   virtual string    Text();                 // Вывод информации

   virtual bool      Save();      // Сохранение состояния
   virtual bool      Load();      // Загрузка состояния

   virtual string    operator~() override;   // Преобразование объекта в строку
};

REGISTER_FACTORABLE_CLASS(CVirtualRiskManager);

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualRiskManager::CVirtualRiskManager(string p_params) {
// Запоминаем строку инициализации
   m_params = p_params;

// Читаем строку инициализации и устанавливаем значения свойств
   m_isActive = (bool) ReadLong(p_params);
   m_baseBalance = ReadDouble(p_params);
   m_calcDailyLossLimit = (ENUM_RM_CALC_DAILY_LOSS) ReadLong(p_params);
   m_maxDailyLossLimit = ReadDouble(p_params);
   m_closeDailyPart = ReadDouble(p_params);
   m_calcOverallLossLimit = (ENUM_RM_CALC_OVERALL_LOSS) ReadLong(p_params);
   m_maxOverallLossLimit = ReadDouble(p_params);
   m_closeOverallPart = ReadDouble(p_params);
   m_calcOverallProfitLimit = (ENUM_RM_CALC_OVERALL_PROFIT) ReadLong(p_params);
   m_maxOverallProfitLimit = ReadDouble(p_params);
   m_maxOverallProfitDate  = (datetime) ReadLong(p_params);
   m_maxRestoreTime = ReadDouble(p_params);
   m_lastVirtualProfitFactor = ReadDouble(p_params);


// Устанавливаем состояние: Лимиты не превышены
   m_state = RM_STATE_OK;
   m_dailyDepoPart = 1;
   m_overallDepoPart = 1;
   m_lastVirtualProfit = 0;
   m_startRestoreTime = 0;

// Запоминаем долю баланса счёта, выделенного на торговлю
   m_baseDepoPart = CMoney::DepoPart();

// Обновляем базовые дневные уровни
   UpdateBaseLevels();

// Корректируем базовый баланс, если он не задан
   if(m_baseBalance == 0) {
      m_baseBalance = m_balance;
   }
}

//+------------------------------------------------------------------+
//| Обработка тика в риск-менеджере                                  |
//+------------------------------------------------------------------+
void CVirtualRiskManager::Tick() {
// Если риск-менеджер неактивен, то выходим
   if(!m_isActive) {
      return;
   }

// Обновляем текущие значения прибыли
   UpdateProfit();

// Если наступил новый дневной период, то обновляем базовые дневные уровни
   if(IsNewBar(Symbol(), PERIOD_D1)) {
      UpdateBaseLevels();
   }

   CheckRestore();

// Проверяем превышение пределов убытка
   CheckLimits();
}

string CVirtualRiskManager::Text() {
   string s = "=== Risk Manager ===\n";
   
   s += m_text + "\n";
   
   return s;
   
}

//+------------------------------------------------------------------+
//| Сохранение состояния                                             |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::Save() {
   CStorage::Set("CVirtualRiskManager::m_state", m_state);
   CStorage::Set("CVirtualRiskManager::m_lastVirtualProfit", m_lastVirtualProfit);
   CStorage::Set("CVirtualRiskManager::m_startRestoreTime", m_startRestoreTime);
   CStorage::Set("CVirtualRiskManager::m_startTime", m_startTime);
   CStorage::Set("CVirtualRiskManager::m_dailyDepoPart", m_dailyDepoPart);
   CStorage::Set("CVirtualRiskManager::m_overallDepoPart", m_overallDepoPart);

   return true;
}

//+------------------------------------------------------------------+
//| Загрузка состояния                                               |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::Load() {
   CStorage::Get("CVirtualRiskManager::m_state", m_state);
   CStorage::Get("CVirtualRiskManager::m_lastVirtualProfit", m_lastVirtualProfit);
   CStorage::Get("CVirtualRiskManager::m_startRestoreTime", m_startRestoreTime);
   CStorage::Get("CVirtualRiskManager::m_startTime", m_startTime);
   CStorage::Get("CVirtualRiskManager::m_dailyDepoPart", m_dailyDepoPart);
   CStorage::Get("CVirtualRiskManager::m_overallDepoPart", m_overallDepoPart);

//m_state = (ENUM_RM_STATE) FileReadNumber(f);
//m_lastVirtualProfit = FileReadNumber(f);
//m_startRestoreTime = FileReadDatetime(f);
//m_startTime = FileReadDatetime(f);
//m_dailyDepoPart = FileReadNumber(f);
//m_overallDepoPart = FileReadNumber(f);

   return true;
}


//+------------------------------------------------------------------+
//| Проверка необходимости восстановления размеров открытых позиций  |
//+------------------------------------------------------------------+
void CVirtualRiskManager::CheckRestore() {
// Если нужно восстанавливать состояние до нормального, то
   if(m_state == RM_STATE_RESTORE) {
      // Проверяем возможность восстановить до нормального множитель дневного убытка
      bool dailyRes = CheckDailyRestore();

      // Проверяем возможность восстановить до нормального множитель общего убытка
      bool overallRes = CheckOverallRestore();

      // Если хотя бы один из них восстановился, то
      if(dailyRes || overallRes) {
         PrintFormat(__FUNCTION__" | VirtualProfit = %.2f | Profit = %.2f | Daily Profit = %.2f",
                     m_virtualProfit, m_profit, m_dailyProfit);
         PrintFormat(__FUNCTION__" | RESTORE: depoPart = %.2f = %.2f * %.2f * %.2f",
                     m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
                     m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

         // Устанавливаем значение используемой части общего баланса
         SetDepoPart();

         // Оповещаем получатель об изменениях
         CVirtualReceiver::Instance().Changed();

         // Если оба множителя восстановлены до нормальных, то
         if(dailyRes && overallRes) {
            // Устанавливаем нормальное состояние
            m_state = RM_STATE_OK;
         }
      }
      //else {
      //   if(IsNewBar(Symbol(), PERIOD_H1)) {
      //      PrintFormat(__FUNCTION__" | VirtualProfit = %.2f | Profit = %.2f | Daily Profit = %.2f",
      //                  m_virtualProfit, m_profit, m_dailyProfit);
      //      PrintFormat(__FUNCTION__" | WAIT RESTORE: depoPart = %.2f = %.2f * %.2f * %.2f",
      //                  m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
      //                  m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);
      //   }
      //}
   }
}

//+------------------------------------------------------------------+
//| Проверка необходимости восстановления дневного множителя         |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::CheckDailyRestore() {
// Если текущая виртуальная прибыль меньше желаемой для восстановления, то
   if(m_virtualProfit <= RestoreVirtualProfit()) {
      // Восстанавливаем множитель дневного убытка
      m_dailyDepoPart = 1.0;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Проверка необходимости восстановления общего множителя           |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::CheckOverallRestore() {
// Если текущая виртуальная прибыль меньше желаемой для восстановления, то
   if(m_virtualProfit <= RestoreVirtualProfit()) {
      // Восстанавливаем множитель общего убытка
      m_overallDepoPart = 1.0;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Максимальный дневной убыток                                      |
//+------------------------------------------------------------------+
double CVirtualRiskManager::DailyLoss() {
   if(m_calcDailyLossLimit == RM_CALC_DAILY_LOSS_PERCENT_BB) {
      // Для заданного процента от базового баланса вычисляем его
      return m_baseBalance * m_maxDailyLossLimit / 100;
   } else if(m_calcDailyLossLimit == RM_CALC_DAILY_LOSS_PERCENT_DL) {
      // Для заданного процента от дневного уровня вычисляем его
      return m_baseDailyLevel * m_maxDailyLossLimit / 100;
   } else {
      // Для фиксированного значения просто возвращаем его
      return m_maxDailyLossLimit;
   }
}

//+------------------------------------------------------------------+
//| Максимальный общий убыток                                        |
//+------------------------------------------------------------------+
double CVirtualRiskManager::OverallLoss() {
   if(m_calcOverallLossLimit == RM_CALC_OVERALL_LOSS_PERCENT_BB) {
      // Для заданного процента от базового баланса вычисляем его
      return m_baseBalance * m_maxOverallLossLimit / 100;
   } else if(m_calcOverallLossLimit == RM_CALC_OVERALL_LOSS_PERCENT_HW_BAL) {
      // Для заданного процента от дневного уровня вычисляем его
      return m_baseHWBalance * m_maxOverallLossLimit / 100;
   } else if(m_calcOverallLossLimit == RM_CALC_OVERALL_LOSS_PERCENT_HW_EQ_BAL) {
      // Для заданного процента от дневного уровня вычисляем его
      return m_baseHWEquityBalance * m_maxOverallLossLimit / 100;
   } else {
      // Для фиксированного значения просто возвращаем его
      // RM_CALC_OVERALL_LOSS_MONEY_BB || RM_CALC_OVERALL_LOSS_MONEY_HW_BAL
      return m_maxOverallLossLimit;
   }
}

//+------------------------------------------------------------------+
//| Максимальный общая прибыль                                       |
//+------------------------------------------------------------------+
double CVirtualRiskManager::OverallProfit() {
// Текущее время
   datetime tc = TimeCurrent();

// Если текущее время больше заданного максимально допустимого, то
   if(m_maxOverallProfitDate && tc > m_maxOverallProfitDate) {
      // Возвращаем значение, гарантирующее закрытие позиций
      return m_overallProfit;
   } else if(m_calcOverallProfitLimit == RM_CALC_OVERALL_PROFIT_PERCENT_BB) {
      // Для заданного процента от базового баланса вычисляем его
      return m_baseBalance * m_maxOverallProfitLimit / 100;
   } else {
      // Для фиксированного значения просто возвращаем его
      // RM_CALC_OVERALL_PROFIT_MONEY_BB
      return m_maxOverallProfitLimit;
   }
}

//+------------------------------------------------------------------+
//| Обновление текущих значений прибыли                              |
//+------------------------------------------------------------------+
void CVirtualRiskManager::UpdateProfit() {
// Текущие средства
   m_equity = AccountInfoDouble(ACCOUNT_EQUITY);

// Текущий баланс
   m_balance = AccountInfoDouble(ACCOUNT_BALANCE);

// Наивысший баланс (High Watermark)
   m_baseHWBalance = MathMax(m_balance, m_baseHWBalance);

// Наивысший баланс или средства (High Watermark)
   m_baseHWEquityBalance = MathMax(m_equity, MathMax(m_balance, m_baseHWEquityBalance));

// Текущая прибыль
   m_profit = m_equity - m_balance;

// Текущая дневная прибыль относительно дневного уровня
   m_dailyProfit = m_equity - m_baseDailyLevel;

// Текущая общая прибыль относительно базового баланса
   m_overallProfit = m_equity - m_baseBalance;

// Если общую прибыль берём относительно наивысшего баланса, то
   if(m_calcOverallLossLimit       == RM_CALC_OVERALL_LOSS_MONEY_HW_BAL
         || m_calcOverallLossLimit == RM_CALC_OVERALL_LOSS_PERCENT_HW_BAL) {
      // Пересчитаем её
      m_overallProfit = m_equity - m_baseHWBalance;
   }

// Если общую прибыль берём относительно наивысшего баланса или средств, то
   if(m_calcOverallLossLimit       == RM_CALC_OVERALL_LOSS_MONEY_HW_EQ_BAL
         || m_calcOverallLossLimit == RM_CALC_OVERALL_LOSS_PERCENT_HW_EQ_BAL) {
      // Пересчитаем её
      m_overallProfit = m_equity - m_baseHWEquityBalance;
   }

// Текущая прибыль виртуальных открытых позиций
   m_virtualProfit = VirtualProfit();
   
   m_text = StringFormat("Virtual = %10.2f | Profit = %8.2f | Daily = %8.2f | Overall = %8.2f"
                  " | depoPart = %.2f = %.2f * %.2f * %.2f",
                  m_virtualProfit, m_profit, m_dailyProfit, m_overallProfit,
                  m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
                  m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

// Раз в час выводим значения в лог
   if(IsNewBar(Symbol(), PERIOD_H1)) {
      PrintFormat(__FUNCTION__" | %s", m_text);
   }
}

//+------------------------------------------------------------------+
//| Обновление дневных базовых уровней                               |
//+------------------------------------------------------------------+
void CVirtualRiskManager::UpdateBaseLevels() {
// Обновляем баланс, средства и базовый дневной уровень
   m_baseDailyBalance = m_balance;
   m_baseDailyEquity = m_equity;
   m_baseDailyLevel = MathMax(m_baseDailyBalance, m_baseDailyEquity);

   m_dailyProfit = m_equity - m_baseDailyLevel;

   PrintFormat(__FUNCTION__" | DAILY UPDATE: Balance = %.2f | Equity = %.2f | Level = %.2f"
               " | depoPart = %.2f = %.2f * %.2f * %.2f",
               m_baseDailyBalance, m_baseDailyEquity, m_baseDailyLevel,
               m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
               m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

// Если ранее был достигнут дневной уровень убытка, то
   if(m_state == RM_STATE_DAILY_LOSS) {
      // Переходим в состояние восстановления размеров открытых позиций
      m_state = RM_STATE_RESTORE;

      // Запоминаем время начала восстановления
      m_startRestoreTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Проверка лимитов убытка                                          |
//+------------------------------------------------------------------+
void CVirtualRiskManager::CheckLimits() {
   if(false
         || CheckDailyLossLimit()     // Проверка дневного лимита
         || CheckOverallLossLimit()   // Проверка общего лимита
         || CheckOverallProfitLimit() // Проверка общей прибыли
     ) {
      // Запоминаем текущий уровень виртуальной прибыли
      m_lastVirtualProfit = m_virtualProfit;

      // Оповещаем получатель об изменениях
      CVirtualReceiver::Instance().Changed();
   }
}

//+------------------------------------------------------------------+
//| Проверка дневного лимита убытка                                  |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::CheckDailyLossLimit() {
// Если достигнут дневной убыток и позиции ещё открыты
   if(m_dailyProfit < -DailyLoss() * (1 - m_dailyDepoPart * (1 - m_closeDailyPart))
         && CMoney::DepoPart() > 0) {

      // Уменьшаем множитель используемой части общего баланса по дневному убытку
      m_dailyDepoPart *= (1 - m_closeDailyPart);

      // Если множитель уже слишком мал, то
      if(m_dailyDepoPart < 0.05) {
         // Устанавливаем его в 0
         m_dailyDepoPart = 0;
      }

      // Устанавливаем значение используемой части общего баланса
      SetDepoPart();

      PrintFormat(__FUNCTION__" | VirtualProfit = %.2f | Profit = %.2f | Daily Profit = %.2f",
                  m_virtualProfit, m_profit, m_dailyProfit);
      PrintFormat(__FUNCTION__" | RESET: depoPart = %.2f = %.2f * %.2f * %.2f",
                  m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
                  m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

      // Устанавливаем риск-менеджер в состояние достигнутого дневного убытка
      m_state = RM_STATE_DAILY_LOSS;

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Проверка общего лимита убытка                                    |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::CheckOverallLossLimit() {
// Если достигнут общий убыток и позиции ещё открыты
   if(m_overallProfit < -OverallLoss() * (1 - m_overallDepoPart * (1 - m_closeOverallPart))
         && CMoney::DepoPart() > 0) {
      // Уменьшаем множитель используемой части общего баланса по общему убытку
      m_overallDepoPart *= (1 - m_closeOverallPart);

      // Если множитель уже слишком мал, то
      if(m_overallDepoPart < 0.05) {
         // Устанавливаем его в 0
         m_overallDepoPart = 0;

         // Устанавливаем риск-менеджер в состояние достигнутого общего убытка
         m_state = RM_STATE_OVERALL_LOSS;
      }

      // Устанавливаем значение используемой части общего баланса
      SetDepoPart();

      PrintFormat(__FUNCTION__" | VirtualProfit = %.2f | Profit = %.2f | Daily Profit = %.2f",
                  m_virtualProfit, m_profit, m_dailyProfit);
      PrintFormat(__FUNCTION__" | RESET: depoPart = %.2f = %.2f * %.2f * %.2f",
                  m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
                  m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Проверка достижения заданной прибыли                             |
//+------------------------------------------------------------------+
bool CVirtualRiskManager::CheckOverallProfitLimit() {
// Если достигнут общий убыток и позиции ещё открыты
   if(m_overallProfit >= OverallProfit() && CMoney::DepoPart() > 0) {
      // Уменьшаем множитель используемой части общего баланса по общему убытку
      m_overallDepoPart = 0;

      // Устанавливаем риск-менеджер в состояние достигнутой общей прибыли
      m_state = RM_STATE_OVERALL_PROFIT;

      // Устанавливаем значение используемой части общего баланса
      SetDepoPart();

      PrintFormat(__FUNCTION__" | VirtualProfit = %.2f | Profit = %.2f | Daily Profit = %.2f",
                  m_virtualProfit, m_profit, m_dailyProfit);
      PrintFormat(__FUNCTION__" | RESET: depoPart = %.2f = %.2f * %.2f * %.2f",
                  m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart,
                  m_baseDepoPart, m_dailyDepoPart, m_overallDepoPart);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Определение прибыли открытых виртуальных позиций                 |
//+------------------------------------------------------------------+
double CVirtualRiskManager::VirtualProfit() {
// Обращаемся к объекту получателя
   CVirtualReceiver *m_receiver = CVirtualReceiver::Instance();

// Устанавливаем исходный множитель использования баланса
   CMoney::DepoPart(m_baseDepoPart);

   double profit = 0;

// Для всех виртуальных позиций находим сумму их прибыли
   FOR(m_receiver.OrdersTotal()) profit += CMoney::Profit(m_receiver.Order(i));

// Восстанавливаем текущий множитель использования баланса
   SetDepoPart();

   return profit;
}

//+------------------------------------------------------------------+
//| Определение прибыли виртуальных позиций для восстановления       |
//+------------------------------------------------------------------+
double CVirtualRiskManager::RestoreVirtualProfit() {
// Если максимальное время восстановления не задано, то
   if(m_maxRestoreTime == 0) {
      // Возвращаем текущее значение виртуальной прибыли
      return m_virtualProfit;
   }

// Находим прошедшее время с начала восстановления в минутах
   double t = (TimeCurrent() - m_startRestoreTime) / 60.0;

// Возвращаем расчётное значение желаемой виртуальной прибыли
// в зависимости от прошедшего времени с начала восстановления
   return m_lastVirtualProfit * m_lastVirtualProfitFactor * (1 - t / m_maxRestoreTime);
}

//+------------------------------------------------------------------+
//| Установка значения используемой части общего баланса             |
//+------------------------------------------------------------------+
void CVirtualRiskManager::SetDepoPart() {
   CMoney::DepoPart(m_baseDepoPart * m_dailyDepoPart * m_overallDepoPart);
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CVirtualRiskManager::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}
//+------------------------------------------------------------------+
