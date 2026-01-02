//+------------------------------------------------------------------+
//|                                                        Money.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.01"

#include "VirtualOrder.mqh"
//+------------------------------------------------------------------+
//| Базовый класс управления капиталом                               |
//+------------------------------------------------------------------+
class CMoney {
   static double     s_depoPart;       // Используемая часть общего баланса
   static double     s_fixedBalance;   // Используемый общий баланс
   
   // Вычисление коэффициента масштабирования объёма виртуальной позиции
   static double     Coeff(CVirtualOrder *p_order);

public:
   CMoney() = delete;                  // Запрещаем конструктор
   
   // Определение расчётного размера виртуальной позиции
   static double     Volume(CVirtualOrder *p_order);
   
   // Определение расчётной прибыли виртуальной позиции  
   static double     Profit(CVirtualOrder *p_order);  

   // Установка и чтение используемой части общего баланса
   static void       DepoPart(double p_depoPart) {
      s_depoPart = p_depoPart;
   }
   static double     DepoPart() {
      return s_depoPart;
   }
   
   // Установка и чтение используемого общего баланса
   static void       FixedBalance(double p_fixedBalance) {
      s_fixedBalance = p_fixedBalance;
   }
   static double     FixedBalance() {
      return s_fixedBalance;
   }
};


double CMoney::s_depoPart = 1.0;
double CMoney::s_fixedBalance = 0;


//+------------------------------------------------------------------+
//| Вычисление коэфф. масштабирования объёма виртуальной позиции     |
//+------------------------------------------------------------------+
double CMoney::Coeff(CVirtualOrder *p_order) {
   // Запрашиваем нормированный баланс стретегии для этой виртуальной позиции
   double fittedBalance = p_order.FittedBalance();

   // Если он равен 0, то коэффициент масштабирования равен 1
   if(fittedBalance == 0.0) {
      return 1;
   }

   // Иначе находим величину общего баланса для торговли
   double totalBalance = s_fixedBalance > 0 ? s_fixedBalance : AccountInfoDouble(ACCOUNT_BALANCE);

   // Возвращаем коэффициент масштабирования объёма
   return totalBalance * s_depoPart / fittedBalance;
}

//+------------------------------------------------------------------+
//| Определение расчётного размера виртуальной позиции                |
//+------------------------------------------------------------------+
double CMoney::Volume(CVirtualOrder *p_order) {
   return p_order.Volume() * Coeff(p_order);
}

//+------------------------------------------------------------------+
//| Определение расчётной прибыли виртуальной позиции                |
//+------------------------------------------------------------------+
double CMoney::Profit(CVirtualOrder *p_order) {
   return p_order.Profit() * Coeff(p_order);
}
//+------------------------------------------------------------------+
