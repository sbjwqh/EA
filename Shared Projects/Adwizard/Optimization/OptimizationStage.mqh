//+------------------------------------------------------------------+
//|                                            OptimizationStage.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17328"
#property version   "1.00"

#include "../Optimization/OptimizationProject.mqh"

//+------------------------------------------------------------------+
//| Класс для этапа оптимизации                                      |
//+------------------------------------------------------------------+
class COptimizationStage {
public:
   ulong             id_stage;
   ulong             id_project;
   ulong             id_parent_stage;
   string            name;
   string            expert;
   string            symbol;
   string            period;
   int               optimization;
   int               model;
   datetime          from_date;
   datetime          to_date;
   int               forward_mode;
   datetime          forward_date;
   int               deposit;
   string            currency;
   int               profit_in_pips;
   int               leverage;
   int               execution_mode;
   int               optimization_criterion;
   string            status;

   COptimizationProject* project;
   COptimizationStage* parent_stage;
   COptimizationJob* jobs[];

                     COptimizationStage(ulong p_idStage, COptimizationProject* p_project, COptimizationStage* parentStage,
                      string p_name, string p_expertName, string p_symbol = "GBPUSD", string p_timeframe = "H1",
                      int p_optimization = 0, int p_model = 0,
                      datetime p_fromDate = 0, datetime p_toDate = 0,
                      int p_forwardMode = 0, datetime p_forwardDate = 0,
                      int p_deposit = 10000, string p_currency = "USD",
                      int p_profitInPips = 0, int p_leverage = 200,
                      int p_executionMode = 0, int p_optimizationCriterion = 7,
                      string p_status = "Done") :
                     id_stage(p_idStage),
                     project(p_project),
                     id_project(!!p_project ? p_project.id_project : 0),
                     parent_stage(parentStage),
                     id_parent_stage(!!parentStage ? parentStage.id_stage : 0),
                     name(p_name), expert(p_expertName), symbol(p_symbol),
                     period(p_timeframe), optimization(p_optimization), model(p_model),
                     from_date(p_fromDate), to_date(p_toDate), forward_mode(p_forwardMode),
                     forward_date(p_forwardDate), deposit(p_deposit), currency(p_currency),
                     profit_in_pips(p_profitInPips), leverage(p_leverage), execution_mode(p_executionMode),
                     optimization_criterion(p_optimizationCriterion), status(p_status) {}

   // Создание этапа в базе данных
   void              Insert();
};

//+------------------------------------------------------------------+
//| Создание этапа в базе данных                                     |
//+------------------------------------------------------------------+
void COptimizationStage::Insert() {
   string query = StringFormat("INSERT INTO stages VALUES("
                               "%s,"  // id_stage
                               "%I64u," // id_project
                               "%s,"    // id_parent_stage
                               "'%s',"  // name
                               "'%s',"  // expert
                               "'%s',"  // symbol
                               "'%s',"  // period
                               "%d,"    // optimization
                               "%d,"    // model
                               "'%s',"  // from_date
                               "'%s',"  // to_date
                               "%d,"    // forward_mode
                               "%s,"    // forward_date
                               "%d,"    // deposit
                               "'%s',"  // currency
                               "%d,"    // profit_in_pips
                               "%d,"    // leverage
                               "%d,"    // execution_mode
                               "%d,"    // optimization_criterion
                               "'%s'"   // status
                               ");",
                               (id_stage == 0 ? "NULL" : (string) id_stage), // id_stage
                               id_project,                          // id_project
                               (id_parent_stage == 0 ?
                                "NULL" : (string) id_parent_stage),   // id_parent_stage
                               name,                           // name
                               expert,                     // expert
                               symbol,                         // symbol
                               period,                      // period
                               optimization,                   // optimization
                               model,                          // model
                               TimeToString(from_date, TIME_DATE),  // from_date
                               TimeToString(to_date, TIME_DATE),    // to_date
                               forward_mode,                    // forward_mode
                               (forward_mode == 4 ?
                                "'" + TimeToString(forward_date, TIME_DATE) + "'"
                                : "NULL"),                         // forward_date
                               deposit,                        // deposit
                               currency,                       // currency
                               profit_in_pips,                   // profit_in_pips
                               leverage,                       // leverage
                               execution_mode,                  // execution_mode
                               optimization_criterion,          // optimization_criterion
                               status                          // status
                              );
   PrintFormat(__FUNCTION__" | %s", query);
   id_stage = DB::Insert(query);
}
//+------------------------------------------------------------------+
