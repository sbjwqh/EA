//+------------------------------------------------------------------+
//|                                               VirtualAdvisor.mqh |
//|                                 Copyright 2019-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.13"

class CVirtualStrategyGroup;

#include "../Base/Advisor.mqh"
#include "../Utils/NewBarEvent.mqh"
#include "../Utils/SymbolsMonitor.mqh"
#include "VirtualCloseManager.mqh"
#include "VirtualRiskManager.mqh"
#include "VirtualInterface.mqh"
#include "VirtualReceiver.mqh"
#include "VirtualStrategyGroup.mqh"
#include "TesterHandler.mqh"

//+------------------------------------------------------------------+
//| Класс эксперта, работающего с виртуальными позициями (ордерами)  |
//+------------------------------------------------------------------+
class CVirtualAdvisor : public CAdvisor {
protected:
   CSymbolsMonitor      *m_symbols;       // Объект монитора символов
   CVirtualReceiver     *m_receiver;      // Объект получателя, выводящий позиции на рынок
   CVirtualInterface    *m_interface;     // Объект интерфейса для показа состояния пользователю
   CVirtualRiskManager  *m_riskManager;   // Объект риск-менеджера
   CVirtualCloseManager *m_closeManager;  // Объект менеджера закрытия

   string            m_fileName;          // Название файла с базой данных эксперта
   datetime          m_lastSaveTime;      // Время последнего сохранения
   bool              m_useOnlyNewBar;     // Обрабатывать только тики нового бара

   datetime          m_fromDate;          // Дата начала работы
   string            m_paramsNorm;        // Параметры группы стратегий после нормировки

   virtual void      Add(CVirtualStrategyGroup *p_group);   // Метод добавления группы стратегий

   static int        s_groupId;           // ID загруженной из базы данных группы стратегий
   CVirtualAdvisor(string p_param);    // Конструктор
public:
   STATIC_CONSTRUCTOR(CVirtualAdvisor);
   ~CVirtualAdvisor();         // Деструктор

   virtual string    operator~() override;      // Преобразование объекта в строку

   virtual void      Tick() override;           // Обработчик события OnTick
   virtual double    Tester() override;         // Обработчик события OnTester

   // Обработчик события OnChartEvent (пока не используется)
   virtual void      ChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam);

   virtual void      Close();          // Закрытие позиций всех стратегий
   virtual string    Text();           // Информация от текущем состоянии советника

   virtual bool      Save();           // Сохранение состояния
   virtual bool      Load();           // Загрузка состояния

   // Замена названий символов
   bool              SymbolsReplace(const string p_symbolsReplace);

   // Проверка наличия новой группы стратегий в базе данных эксперта
   bool              CheckUpdate();

   // Экспорт текущей группы стратегий в заданную базу данных эксперта
   void              Export(string p_groupName, string p_advFileName);

   // Обработчик события OnTesterInit
   static int        TesterInit(ulong p_idTask = 0, string p_fileName = NULL);
   static void       TesterPass();     // Обработчик события OnTesterDeinit
   static void       TesterDeinit();   // Обработчик события OnTesterDeinit

   // Имя файла с базой данных эксперта
   static string     FileName(string p_name, ulong p_magic = 1);

   // Получение строки инициализации группы стратегий
   // из базы данных эксперта с заданным идентификатором
   static string     Import(string p_fileName, int p_groupId = 0);
};

int CVirtualAdvisor::s_groupId = 0;

REGISTER_FACTORABLE_CLASS(CVirtualAdvisor);


//+------------------------------------------------------------------+
//| Метод добавления группы стратегий                                |
//+------------------------------------------------------------------+
void CVirtualAdvisor::Add(CVirtualStrategyGroup *p_group) {
// Если в этой группе содержатся другие группы, то добавляем каждую из них
   FOREACH(p_group.m_groups) {
      CVirtualAdvisor::Add(p_group.m_groups[i]);
      delete p_group.m_groups[i];
   }
// Если в этой группе содержатся стратегии, то добавляем каждую из них
   FOREACH(p_group.m_strategies) CAdvisor::Add(p_group.m_strategies[i]);
}

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualAdvisor::CVirtualAdvisor(string p_params) {
// Запоминаем строку инициализации
   m_params = p_params;

// Читаем строку инициализации объекта группы стратегий
   string groupParams = ReadObject(p_params);

// Читаем строку инициализации объекта риск-менеджера
   string riskManagerParams = NULL;

   if(IsObjectOf(p_params, "CVirtualRiskManager")) {
      riskManagerParams = ReadObject(p_params);
   }

// Читаем строку инициализации объекта менеджера закрытия
   string closeManagerParams = NULL;
   if(IsObjectOf(p_params, "CVirtualCloseManager")) {
      closeManagerParams = ReadObject(p_params);
   }

// Читаем магический номер
   ulong p_magic = ReadLong(p_params);

// Читаем название эксперта
   string p_name = ReadString(p_params);

// Читаем признак работы на только на открытии бара
   m_useOnlyNewBar = (bool) ReadLong(p_params);

// Если нет ошибок чтения, то
   if(IsValid()) {
// Создаём группу стратегий
      CREATE(CVirtualStrategyGroup, p_group, groupParams);

      // Инициализируем монитор символов статическим монитором символов
      m_symbols = CSymbolsMonitor::Instance();

      // Инициализируем получателя статическим получателем
      m_receiver = CVirtualReceiver::Instance(p_magic);

      // Инициализируем интерфейс статическим интерфейсом
      m_interface = CVirtualInterface::Instance(p_magic);

      // Деактивируем интерфейс, так как он будет сильно переделан
      m_interface.Deactivate();

      // Формируем из имени эксперта и параметров имя файла базы данных эксперта для сохранения состояния
      m_fileName = FileName(p_name, p_magic);

      // Запоминаем время начала работы (тестирования)
      m_fromDate = TimeCurrent();

      // Сбрасываем время последнего сохранения
      m_lastSaveTime = 0;

      // Добавляем к эксперту содержимое группы
      Add(p_group);

      // Удаляем объект группы
      delete p_group;

      // Создаём объект риск-менеджера
      if(riskManagerParams != NULL) {
         m_riskManager = NEW(riskManagerParams);

         // Если риск-менеджер неактивен, то удаляем его объект
         if(!m_riskManager.IsActive()) {
            delete m_riskManager;
         }
      }

      // Создаём объект менеджера закрытия
      if(closeManagerParams != NULL) {
         m_closeManager = NEW(closeManagerParams);

         // Привязываем эксперта к менеджеру закрытия
         m_closeManager.Expert(&this);

         // Если риск-менеджер неактивен, то удаляем его объект
         if(!m_closeManager.IsActive()) {
            delete m_closeManager;
         }

      }
   }
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
void CVirtualAdvisor::~CVirtualAdvisor() {
   if(!!m_symbols)      delete m_symbols;       // Удаляем монитор символов
   if(!!m_receiver)     delete m_receiver;      // Удаляем получатель
   if(!!m_interface)    delete m_interface;     // Удаляем интерфейс
   if(!!m_riskManager)  delete m_riskManager;   // Удаляем риск-менеджер
   if(!!m_closeManager) delete m_closeManager;  // Удаляем менеджер закрытия
   DestroyNewBar();           // Удаляем объекты отслеживания нового бара
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CVirtualAdvisor::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}

//+------------------------------------------------------------------+
//| Обработчик события OnTick                                        |
//+------------------------------------------------------------------+
void CVirtualAdvisor::Tick(void) {
// Определяем новый бар по всем нужным символам и таймфреймам
   bool isNewBar = UpdateNewBar();

// Если нигде нового бара нет, а мы работаем только по новым барам, то выходим
   if(!isNewBar && m_useOnlyNewBar) {
      return;
   }

// Монитор символов обновляет котировки
   m_symbols.Tick();

// Получатель обрабатывает виртуальные позиции
   m_receiver.Tick();

// Запуск обработки в стратегиях
   CAdvisor::Tick();

// Риск-менеджер обрабатывает виртуальные позиции
   if(!!m_riskManager) m_riskManager.Tick();

// Риск-менеджер обрабатывает виртуальные позиции
   if(!!m_closeManager) m_closeManager.Tick();

// Корректировка рыночных объемов
   m_receiver.Correct();

// Сохранение состояния
   Save();

// Отрисовка интерфейса
   m_interface.Redraw();
}

//+------------------------------------------------------------------+
//| Обработчик события OnTester                                      |
//+------------------------------------------------------------------+
double CVirtualAdvisor::Tester() {
// Максимальная абсолютная просадка
   double balanceDrawdown = TesterStatistics(STAT_EQUITY_DD);

// Прибыль
   double profit = TesterStatistics(STAT_PROFIT);

// Фиксированный баланс для торговли из настроек
   double fixedBalance = CMoney::FixedBalance();

// Коэффициент возможного увеличения размеров позиций для просадки 10% от fixedBalance_
   double coeff = fixedBalance * 0.1 / MathMax(1, balanceDrawdown);

// Пресчитываем прибыль в годовую
   long totalSeconds = TimeCurrent() - m_fromDate;
   double totalYears = totalSeconds / (365.0 * 24 * 3600);
   double fittedProfit = profit * coeff / totalYears;

// Если он не указан, то берём начальный баланс (хотя это будет давать искажённый результат)
   if(fixedBalance < 1) {
      fixedBalance = TesterStatistics(STAT_INITIAL_DEPOSIT);
      balanceDrawdown = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
      coeff = 0.1 / MathMax(1, balanceDrawdown);
      fittedProfit = fixedBalance * MathPow(1 + profit * coeff / fixedBalance, 1 / totalYears);
   }

// Воссоздаём группу использованных стратегий для последующей нормировки
   CVirtualStrategyGroup* group = NEW(ReadObject(m_params));

   if(!!group) {
      // Строка инициализации нормированной группы
      m_paramsNorm = group.ToStringNorm(coeff);

      FOREACH(m_strategies) ((CVirtualStrategy*)m_strategies[i]).Scale(coeff);

      // Выполняем формирование фрейма данных на агенте тестирования
      CTesterHandler::Tester(fittedProfit,   // Нормированная прибыль
                             m_paramsNorm     // Строка инициализации нормированной группы
                            );

      PrintFormat(__FUNCTION__" | Scale = %.2f\nParams:\n%s", coeff, m_paramsNorm);
      PrintFormat(__FUNCTION__" | Scale = %.2f", coeff);

      delete group;
   }

   PrintFormat(__FUNCTION__" |\n%s = %.2f\n%s = %.2f\n%s = %.2f\n%s = %.2f\n%s = %.2f\n",
               EnumToString(STAT_BALANCE_DD), TesterStatistics(STAT_BALANCE_DD),
               EnumToString(STAT_BALANCE_DD_RELATIVE), TesterStatistics(STAT_BALANCE_DD_RELATIVE),
               EnumToString(STAT_EQUITY_DD), TesterStatistics(STAT_EQUITY_DD),
               EnumToString(STAT_EQUITY_DD_RELATIVE), TesterStatistics(STAT_EQUITY_DD_RELATIVE),
               EnumToString(STAT_EQUITY_DDREL_PERCENT), TesterStatistics(STAT_EQUITY_DDREL_PERCENT)
              );

   return fittedProfit;
}

//+------------------------------------------------------------------+
//| Экспорт текущей группы стратегий в заданную базу данных эксперта |
//+------------------------------------------------------------------+
void CVirtualAdvisor::Export(string p_groupName, string p_advFileName) {
   CTesterHandler::Export(m_strategies, p_groupName, p_advFileName);
}

//+------------------------------------------------------------------+
//| Обработчик событий ChartEvent                                    |
//+------------------------------------------------------------------+
void CVirtualAdvisor::ChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   m_interface.ChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Закрытие позиций всех стратегий                                  |
//+------------------------------------------------------------------+
void CVirtualAdvisor::Close(void) {
// Для всех стратегий вызываем метод закрытия виртуальных позиций
   FOREACH(m_strategies) ((CVirtualStrategy *)m_strategies[i]).Close();
}

//+------------------------------------------------------------------+
//| Информация от текущем состоянии советника                        |
//+------------------------------------------------------------------+
string CVirtualAdvisor::Text() {
   string s = "";

   s += StringFormat("Symbols: %s\n", m_symbols.SymbolsNames());
   s += StringFormat("Strategies: %5d total\n", ArraySize(m_strategies));

   if(!!m_closeManager)
      s += m_closeManager.Text();

   if(!!m_riskManager)
      s += m_riskManager.Text();

   return s;
}

//+------------------------------------------------------------------+
//| Инициализация перед началом оптимизации                                                                 |
//+------------------------------------------------------------------+
int CVirtualAdvisor::TesterInit(ulong p_idTask, string p_fileName) {
   return CTesterHandler::TesterInit(p_idTask, p_fileName);
}

//+------------------------------------------------------------------+
//| Действия после завершения очередного прохода при оптимизации     |
//+------------------------------------------------------------------+
void CVirtualAdvisor::TesterPass() {
   CTesterHandler::TesterPass();
}


//+------------------------------------------------------------------+
//| Действия после завершения оптимизации                            |
//+------------------------------------------------------------------+
void CVirtualAdvisor::TesterDeinit() {
   CTesterHandler::TesterDeinit();
}


//+------------------------------------------------------------------+
//| Сохранение состояния                                             |
//+------------------------------------------------------------------+
bool CVirtualAdvisor::Save() {
// Сохраняем состояние, если:
   if(true
// появились более поздние изменения
         && m_lastSaveTime < CVirtualReceiver::s_lastChangeTime
// и сейчас не оптимизация
         && !MQLInfoInteger(MQL_OPTIMIZATION)
// и сейчас не тестирование либо сейчас визуальное тестирование
         && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
     ) {
      // Если подключение к базе данных эксперта установлено
      if(CStorage::Connect(m_fileName)) {
         // Сохраняем время последних изменений
         CStorage::Set("CVirtualReceiver::s_lastChangeTime", CVirtualReceiver::s_lastChangeTime);
         CStorage::Set("CVirtualAdvisor::s_groupId", CVirtualAdvisor::s_groupId);

         // Сохраняем все стратегии
         FOREACH(m_strategies) ((CVirtualStrategy*) m_strategies[i]).Save();

         // Сохраняем риск-менеджер
         if (!!m_riskManager) m_riskManager.Save();

         // Сохраняем менеджер закрытия
         if (!!m_closeManager) m_closeManager.Save();

         // Обновляем время последнего сохранения
         m_lastSaveTime = CVirtualReceiver::s_lastChangeTime;
         PrintFormat(__FUNCTION__" | OK at %s to %s",
                     TimeToString(m_lastSaveTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                     m_fileName);

         // Закрываем соединение
         CStorage::Close();

         // Возвращаем результат
         return CStorage::Res();
      } else {
         PrintFormat(__FUNCTION__" | ERROR: Can't open database [%s], LastError=%d",
                     m_fileName, GetLastError());
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Загрузка состояния                                               |
//+------------------------------------------------------------------+
bool CVirtualAdvisor::Load() {
   bool res = true;
   ulong groupId = 0;

// Загружаем состояние, если:
   if(true
// файл существует
         && FileIsExist(m_fileName, FILE_COMMON)
// и сейчас не оптимизация
         && !MQLInfoInteger(MQL_OPTIMIZATION)
// и сейчас не тестирование либо сейчас визуальное тестирование
         && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
     ) {
      // Если подключение к базе данных эксперта установлено
      if(CStorage::Connect(m_fileName)) {
         // Если время последних изменений загружено и меньше текущего времени
         if(CStorage::Get("CVirtualReceiver::s_lastChangeTime", m_lastSaveTime)
               && m_lastSaveTime <= TimeCurrent()) {

            PrintFormat(__FUNCTION__" | LAST SAVE at %s",
                        TimeToString(m_lastSaveTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));

            // Если идентификатор сохранённой группы стратегий загружен
            if(CStorage::Get("CVirtualAdvisor::s_groupId", groupId)) {
               // Загружаем все стратегии, игнорируя возможные ошибки
               FOREACH(m_strategies) {
                  res &= ((CVirtualStrategy*) m_strategies[i]).Load();
               }

               if(groupId != s_groupId) {
                  // Действия при запуске эксперта с новой группой стратегий.
                  PrintFormat(__FUNCTION__" | UPDATE Group ID: %I64u -> %I64u", groupId, s_groupId);

                  // Сбрасываем возможный признак ошибки при загрузке стратегий
                  res = true;

                  string symbols[]; // Массив для названий символоа

                  // Получаем список всех используемых предыдущей группой символов
                  CStorage::GetSymbols(symbols);

                  // Для всех символов создаём символьный получатель.
                  // Это нужно для корректного закрытия виртуальных позиций
                  // старой группы стратегий сразу после загрузки новой
                  FOREACH(symbols) m_receiver[symbols[i]];
               }

               if(res) {
                  // Загружаем риск-менеджер
                  if(!!m_riskManager) {
                     res &= m_riskManager.Load();

                     if(!res) {
                        PrintFormat(__FUNCTION__" | ERROR loading risk manager from DB [%s]", m_fileName);
                     }
                  }

                  // Загружаем менеджер закрытия
                  if(!!m_closeManager) {
                     res &= m_closeManager.Load();

                     if(!res) {
                        PrintFormat(__FUNCTION__" | ERROR loading close manager from DB [%s]", m_fileName);
                     }
                  } else              {
                     PrintFormat(__FUNCTION__" | ERROR loading strategies from DB [%s]", m_fileName);
                  }
               }
            }
         } else {
            // Если время последних изменений не найдено или находится в будущем,
            // то начинаем работу с чистого листа
            PrintFormat(__FUNCTION__" | NO LAST SAVE [%s] - Clear Storage",
                        TimeToString(m_lastSaveTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
            CStorage::Clear();
            m_lastSaveTime = 0;
         }

         // Закрываем соединение
         CStorage::Close();
      }
   }

   return res;
}

//+------------------------------------------------------------------+
//| Замена названий символов                                         |
//+------------------------------------------------------------------+
bool CVirtualAdvisor::SymbolsReplace(string p_symbolsReplace) {
// Избавляемся от пробелов в строке замен
   StringReplace(p_symbolsReplace, " ", "");

// Если строка замен пустая, то ничего не делаем
   if(p_symbolsReplace == "") {
      return true;
   }

// Переменная для результата
   bool res = true;

   string symbolKeyValuePairs[]; // Массив для отдельных замен
   string symbolPair[];          // Массив для двух имён в одной замене

// Делим строку замен на части, представляющие одну отдельную замену
   StringSplit(p_symbolsReplace, ';', symbolKeyValuePairs);

// Словарь для соответствия целевого символа исходному символу
   CHashMap<string, string> symbolsMap;

// Для всех отдельных замен
   FOREACH(symbolKeyValuePairs) {
      // Получаем исходный и целевой символы как два элемента массива
      StringSplit(symbolKeyValuePairs[i], '=', symbolPair);

      // Проверяем наличие целевого символа в списке доступных символов (не кастомных)
      bool custom = false;
      res &= SymbolExist(symbolPair[1], custom);

      // Если целевой символ не найден, то сообщаем об ошибке и выходим
      if(!res) {
         PrintFormat(__FUNCTION__" | ERROR: Target symbol %s for mapping %s not found", symbolPair[1], symbolKeyValuePairs[i]);
         return res;
      }

      // Добавляем в словарь новый элемент: ключ - исходный символ, значение - целевой символ
      res &= symbolsMap.Add(symbolPair[0], symbolPair[1]);

      // Если целевой символ не удалось добавить в словарь, то сообщаем об ошибке и выходим
      if(!res) {
         PrintFormat(__FUNCTION__" | ERROR: Can't add symbol map pair %s to HashMap. Check your parameter:\n%s",
                     symbolKeyValuePairs[i], p_symbolsReplace);
         return res;
      }
   }

// Если ошибок не возникло, то для всех стратегий вызываем соответствующий метод замены
   FOREACH(m_strategies) res &= ((CVirtualStrategy*) m_strategies[i]).SymbolsReplace(symbolsMap);

   return res;
}

//+------------------------------------------------------------------+
//| Проверка наличия новой группы стратегий в базе данных эксперта   |
//+------------------------------------------------------------------+
bool CVirtualAdvisor::CheckUpdate() {
// Запрос на получение стратегий заданной группы либо последней группы
   string query = StringFormat("SELECT MAX(id_group) FROM strategy_groups"
                               " WHERE to_date <= '%s'",
                               TimeToString(TimeCurrent(), TIME_DATE));

// Открываем базу данных эксперта
   if(DB::Connect(m_fileName, DB_TYPE_ADV)) {
// Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      // Если нет ошибки
      if(request != INVALID_HANDLE) {
         // Структура данных для чтения одной строки результата запроса
         struct Row {
            int      groupId;
         } row;

         // Читаем данные из первой строки результата
         while(DatabaseReadBind(request, row)) {
            // Если новый идентификатор группы стратегий
            // больше уже используемого, то можно перейти на новую группу стратегий
            if(s_groupId < row.groupId) {
               PrintFormat(__FUNCTION__" | CAN UPDATE to new strategy group %d", row.groupId);
               return true;
            }
         }
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
      }

      // Закрываем базу данных эксперта
      DB::Close();
   }

   return false;
}

//+------------------------------------------------------------------+
//| Получение строки инициализации группы стратегий                  |
//| из базы данных эксперта с заданным идентификатором               |
//+------------------------------------------------------------------+
string CVirtualAdvisor::Import(string p_fileName, int p_groupId = 0) {
   string params[];   // Массив для строк инициализации стратегий

// Запрос на получение стратегий заданной группы либо последней группы
   string query = StringFormat("SELECT s.id_group, sg.name, s.params "
                               "  FROM strategies s INNER JOIN strategy_groups sg ON s.id_group=sg.id_group"
                               " WHERE s.id_group IN (%s);",
                               (p_groupId > 0 ? (string) p_groupId
                                : "(SELECT MAX(id_group) FROM strategy_groups WHERE to_date <= '"
                                + TimeToString(TimeCurrent(), TIME_DATE) +
                                "')"));


// Открываем базу данных эксперта
   if(DB::Connect(p_fileName, DB_TYPE_ADV)) {
      // Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      // Если нет ошибки
      if(request != INVALID_HANDLE) {
         // Структура данных для чтения одной строки результата запроса
         struct Row {
            int      groupId;
            string   name;
            string   params;
         } row;

         // Читаем данные из первой строки результата
         while(DatabaseReadBind(request, row)) {
            // Запоминаем идентификатор группы стратегий
            // в статическом свойстве класса эксперта
            s_groupId = row.groupId;
            PrintFormat(__FUNCTION__" | IMPORT group: %s\n%s", row.name, query);

            // Добавляем очередную строку инициализации стратегии в массив
            APPEND(params, row.params);
         }
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
      }

      // Закрываем базу данных эксперта
      DB::Close();
   }

// Строка инициализации группы стратегий
   string groupParams = NULL;

// Общее количество стратегий в группе
   int totalStrategies = ArraySize(params);

// Если стратегии есть, то
   if(totalStrategies > 0) {
      // Соединяем их строки инициализации через запятую
      JOIN(params, groupParams, ",");

      // Создаём строку инициализации группы стратегий
      groupParams = StringFormat("class CVirtualStrategyGroup([%s], %.5f)",
                                 groupParams,
                                 totalStrategies);
   }

// Возвращаем строку инициализации группы стратегий
   return groupParams;
}

//+------------------------------------------------------------------+
//| Имя файла с базой данных эксперта                                |
//+------------------------------------------------------------------+
string CVirtualAdvisor::FileName(string p_name, ulong p_magic = 1) {
   return StringFormat("%s-%d%s.db.sqlite",
                       (p_name != "" ? p_name : "Expert"),
                       p_magic,
                       (MQLInfoInteger(MQL_TESTER) ? ".test" : "")
                      );
}
//+------------------------------------------------------------------+
