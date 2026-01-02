//+------------------------------------------------------------------+
//|                                            FactorableCreator.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.00"

#include "../Utils/Macros.mqh"

// Предварительное определение класса
class CFactorable;

// Объявление типа - указатель на функцию создания объектов класса CFactorable
typedef CFactorable* (*TCreateFunc)(string);

//+------------------------------------------------------------------+
//| Класс создателей, связывающих названия и статические             |
//| конструкторы классов-наследников CFactorable                     |
//+------------------------------------------------------------------+
class CFactorableCreator {
public:
   string            m_className;   // Название класса
   TCreateFunc       m_creator;     // Статический конструктор для этого класса

   // Конструктор создателя
                     CFactorableCreator(string p_className, TCreateFunc p_creator);

   // Статический массив всех созданных объектов-создателей
   static CFactorableCreator* creators[];
};

// Статический массив всех созданных объектов-создателей
CFactorableCreator* CFactorableCreator::creators[];

//+------------------------------------------------------------------+
//| Конструктор создателя                                            |
//+------------------------------------------------------------------+
CFactorableCreator::CFactorableCreator(string p_className, TCreateFunc p_creator) :
   m_className(p_className),
   m_creator(p_creator) {
// Добавляем текущий объект создателя в статический массив
   APPEND(creators, &this);
}
//+------------------------------------------------------------------+
