//+------------------------------------------------------------------+
//|                                                   Factorable.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.06"

#include "FactorableCreator.mqh"

// Объявление статического конструктора внутри класса
#define STATIC_CONSTRUCTOR(C) static CFactorable* Create(string p) { return new C(p); }

// Добавление статического конструктора для нового класса-наследника CFactorable
// в специальный массив через создание глобального объекта класса CFactorableCreator
#define REGISTER_FACTORABLE_CLASS(C) CFactorableCreator C##Creator(#C, C::Create);

// Создание объекта на фабрике из строки
#define NEW(P) CFactorable::Create(P)

// Создание дочернего объекта на фабрике из строки c проверкой.
// Вызывается только из конструктора текущего объекта.
// Если объект не создан, то текущий объект становится невалидным
// и осуществляется выход из конструктора
#define CREATE(C, O, P) C *O = NULL; if (IsValid()) { O = dynamic_cast<C*> (NEW(P)); if(!O) { SetInvalid(__FUNCTION__, StringFormat("Expected Object of class %s() at line %d in Params:\n%s", #C, __LINE__, P)); return; }}


//+------------------------------------------------------------------+
//| Базовый класс объектов, создаваемых из строки                    |
//+------------------------------------------------------------------+
class CFactorable {
private:
   bool              m_isValid;  // Объект исправный?

   // Очистка пустых символов слева и справа в строке инициализации
   static void       Trim(string &p_params);

   // Поиск парной закрывающей скобки в строке инициализации
   static int        FindCloseBracket(string &p_params, char closeBraket = ')');

   // Очистка строки инициализации с проверкой на исправность текущего объекта
   bool              CheckTrimParams(string &p_params);

protected:
   string            m_params;   // Строка инициализации текущего объекта
   bool              m_isActive; // Объект активен?

   // Установка текущего объекта в неисправное состояние
   void              SetInvalid(string function = NULL, string message = NULL);

public:
   CFactorable() :
      m_isValid(true),
      m_isActive(true) {}  // Конструктор

   bool              IsValid();                          // Объект исправный?
   bool              IsActive();                         // Объект активный?

   // Преобразование объекта в строку
   virtual string    operator~() = 0;

   // Строка инициалазации начинается с определения объекта?
   static bool       IsObject(string &p_params, const string className = "");

   // Строка инициалазации начинается с определения объекта нужного класса?
   static bool       IsObjectOf(string &p_params, const string className);

   // Чтение имени класса объекта из строки инициализации
   static string     ReadClassName(string &p_params, bool p_removeClassName = true);

   // Чтение объекта из строки инициализации
   string            ReadObject(string &p_params);

   // Чтение массива из строки инициализации в виде строки
   string            ReadArrayString(string &p_params);

   // Чтение строки из строки инициализации
   string            ReadString(string &p_params);

   // Чтение числа из строки инициализации в виде строки
   string            ReadNumber(string &p_params);

   // Чтение вещественного числа из строки инициализации
   double            ReadDouble(string &p_params);

   // Чтение целого числа из строки инициализации
   long              ReadLong(string &p_params);

   // Вычисление MD5-хеша строки
   static string     Hash(string p_params, string delimeter = "");
   virtual string    Hash() {
      return CFactorable::Hash(m_params);
   }

   // Создание объекта из строки инициализации
   static CFactorable* Create(string p_params);
};


//+------------------------------------------------------------------+
//| Очистка пустых символов слева и справа в строке инициализации    |
//+------------------------------------------------------------------+
void CFactorable::Trim(string &p_params) {
// Позиция слева, с которой начинается содержимое строки инициализации
   int posBeg = 0;

// Если в начале идёт одна запятая, то сдвигаемся вправо
   if(p_params[posBeg] == ',') posBeg++;

// Пока идут пробельные символы, сдвигаемся вправо
   while(false
         || p_params[posBeg] == '\r'
         || p_params[posBeg] == '\n'
         || p_params[posBeg] == '\t'
         || p_params[posBeg] == ' ') {
      posBeg++;
   }

// Если дальше идёт одна запятая, то ещё сдвигаемся вправо
   if(p_params[posBeg] == ',') posBeg++;

// Вырезаем незначащую левую часть строки инициализации
   p_params = StringSubstr(p_params, posBeg);

// Позиция справа, на которой заканчивается содержательная
// часть строки инициализации
   int posEnd = StringLen(p_params) - 1;

// Если в конце идёт одна запятая, то сдвигаемся влево
   if(p_params[posEnd] == ',') posEnd--;

// Пока идут пробельные символы, сдвигаемся влево
// но не дальше начала строки
   while(posEnd >= 0 && (false
                         || p_params[posEnd] == '\r'
                         || p_params[posEnd] == '\n'
                         || p_params[posEnd] == '\t'
                         || p_params[posEnd] == ' ')) {
      posEnd--;
   }

// Если дальше идёт одна запятая, то ещё сдвигаемся влево
   if(p_params[posEnd] == ',') posEnd--;

// Вырезаем незначащую правую часть строки инициализации
   p_params = StringSubstr(p_params, 0, posEnd + 1);
}

//+------------------------------------------------------------------+
//| Поиск парной закрывающей скобки в строке инициализации           |
//+------------------------------------------------------------------+
int CFactorable::FindCloseBracket(string &p_params, char closeBraket) {
// Cчётчик скобок
   int count = 0;
// Парная скобка
   char openBraket = (closeBraket == ')' ? '(' : '[');

// Находим первую открывающую скобку
   int pos;
   for(pos = 0; pos < StringLen(p_params); pos++) {
      if(p_params[pos] == openBraket) break;
   }

// Далее увеличиваем счётчик для открывающих и уменьшаем для закрывающих
   for(; pos < StringLen(p_params); pos++) {
      if(p_params[pos] == openBraket ) count++;
      if(p_params[pos] == closeBraket) count--;

      // Когда счётчик стал равен 0, то мы нашли парную закрывающую скобку
      if(count == 0) {
         return pos;
      }
   }
// Иначе скобка не найдена
   return -1;
}

//+------------------------------------------------------------------+
//| Очистка строки инициализации с проверкой на исправность          |
//| текущего объекта                                                 |
//+------------------------------------------------------------------+
bool CFactorable::CheckTrimParams(string &p_params) {
// Если текущий объект уже в неисправном состоянии, то вернуть false
   if(!IsValid()) return false;
// Очистим строку инициализации
   Trim(p_params);
// Вернём результат проверки, что строка инициализации не пустая
   return (p_params != NULL && p_params != "");
}

//+------------------------------------------------------------------+
//| Установка текущего объекта в неисправное состояние               |
//+------------------------------------------------------------------+
void CFactorable::SetInvalid(string function, string message) {
// Если объект ещё в исправном состоянии,
   if(IsValid()) {
      // то устанавливаем его в неисправное состояние
      m_isValid = false;
      if(function != NULL) {
         // Сообщаем об ошибке, если переданно имя вызывающей функции
         PrintFormat("%s | ERROR: %s", function, message);
      }
   } else {
      // Иначе просто сообщаем об ошибке, если переданно имя вызывающей функции
      if(function != NULL) {
         PrintFormat("%s | ERROR: Object is invalid already", function);
      }
   }
}

//+------------------------------------------------------------------+
//|  Объект исправный?                                               |
//+------------------------------------------------------------------+
bool CFactorable::IsValid() {
   return m_isValid;
}

//+------------------------------------------------------------------+
//|  Объект активный?                                               |
//+------------------------------------------------------------------+
bool CFactorable::IsActive() {
   return m_isActive;
}

//+------------------------------------------------------------------+
//| Строка инициалазации начинается с определения объекта?           |
//+------------------------------------------------------------------+
bool CFactorable::IsObject(string &p_params, const string className = "") {
// Возвращаем результат проверки, что в начале идет слово 'class'
// с возможным именем класса после одного пробела
   Trim(p_params);
   return (StringFind(p_params, "class " + className) == 0);
}

//+------------------------------------------------------------------+
//| Строка инициалазации начинается с определения объекта            |
//| нужного класса?                                                  |
//+------------------------------------------------------------------+
bool CFactorable::IsObjectOf(string &p_params, const string className) {
   return IsObject(p_params, className);
}

//+------------------------------------------------------------------+
//| Чтение имени класса объекта из строки инициализации              |
//+------------------------------------------------------------------+
string CFactorable::ReadClassName(string &p_params,
                                  bool p_removeClassName = true) {
// Очищаем пустые символы в начале и конце
   Trim(p_params);

// Если строка инициализации пустая, то ничего не делаем
   if(p_params == NULL || p_params == "") {
      return NULL;
   }

   string res = NULL;
// Начальная позиция - длина слова 'class '
   int posBeg = 6;
// Конечная позиция - открывающая скобка после имени класса
   int posEnd = StringFind(p_params, "(");

// Если в строке есть имя класса и параметры в скобках
   if(IsObject(p_params) && posEnd != -1) {
      // Вырезаем имя класса в качестве результата
      res = StringSubstr(p_params, posBeg, posEnd - posBeg);
      // Если в строке инициализации надо оставить только параметры, то
      if(p_removeClassName) {
         // Убираем из строки инициализации имя класса со скобками
         p_params = StringSubstr(p_params, posEnd + 1, StringLen(p_params) - posEnd - 2);
      }
   }
// Возвращаем результат
   return res;
}


//+------------------------------------------------------------------+
//| Чтение объекта из строки инициализации                           |
//+------------------------------------------------------------------+
string CFactorable::ReadObject(string &p_params) {
// Если строка инициализации не пустая и текущий объект ещё в исправном состоянии
   if(CheckTrimParams(p_params)) {
      // Если строка инициализации содержит описание объекта
      if(IsObject(p_params)) {
         // Находим положение скобки, закрывающей описание параметров объекта
         int posEnd = FindCloseBracket(p_params, ')');
         if(posEnd != -1) {
            // Всё до этой скобки включительно берём в качестве результата
            string res = StringSubstr(p_params, 0, posEnd + 1);
            // Убираем возвращаемую часть из строки инициализации
            p_params = StringSubstr(p_params, posEnd + 1);
            if(p_params == "") p_params = NULL;
            // Возвращаем результат
            return res;
         }
      }
   }
// Иначе устанавливаем текущий объект в неисправное состояние и сообщаем об ошибке
   SetInvalid(__FUNCTION__, StringFormat("Expected Object in Params:\n%s", p_params));

   return NULL;
}

//+------------------------------------------------------------------+
//| Чтение массива из строки инициализации в виде строки             |
//+------------------------------------------------------------------+
string CFactorable::ReadArrayString(string &p_params) {
// Если строка инициализации не пустая и текущий объект ещё в исправном состоянии
   if(CheckTrimParams(p_params)) {
      // Позиция конца описания массива
      int posEnd = -1;

      // Если в начале идёт открвающая массив скобка, то
      if(p_params[0] == '[') {
         // Находим позицию закрывающей скобки
         posEnd = FindCloseBracket(p_params, ']');
         // Если нашли, то
         if(posEnd != -1) {
            // Всё до этой скобки не доходя берём в качестве результата
            string res = StringSubstr(p_params, 1, posEnd - 1);
            // Очищаем пустые символы в начале и конце
            Trim(res);
            if(res == "") res = NULL;

            // Убираем возвращаемую часть вместе со скобкой из строки инициализации
            p_params = StringSubstr(p_params, posEnd + 1);
            if(p_params == "") p_params = NULL;

            // Возвращаем результат
            return res;
         }
      }
   }
// Иначе устанавливаем текущий объект в неисправное состояние и сообщаем об ошибке
   SetInvalid(__FUNCTION__, StringFormat("Expected Array in Params:\n%s", p_params));

   return NULL;
}

//+------------------------------------------------------------------+
//| Чтение строки из строки инициализации                            |
//+------------------------------------------------------------------+
string CFactorable::ReadString(string &p_params) {
// Если строка инициализации не пустая и текущий объект ещё в исправном состоянии
   if(CheckTrimParams(p_params)) {
      // Если это не описание массива и не описание объекта
      if(p_params[0] != '[' && !IsObject(p_params)) {
         // Позиция окончания читаемой строки
         int posEnd = -1;
         // Строка идет в кавычках?
         int quoted = (p_params[0] == '"' ? 1 : 0);

         // Если в кавычках, то
         if(quoted) {
            // Находим следующий символ кавычек
            posEnd = StringFind(p_params, "\"", 1);
            // Если не найден, то устанавливаем текущий объект в неисправное состояние с сообщением об ошибке
            if(posEnd == -1) {
               SetInvalid(__FUNCTION__, StringFormat("Closed quote not found in Params:\n%s", p_params));
               return NULL;
            }
            // Отступаем влево от закрывающей кавычки
            posEnd--;
         } else {
            // Иначе находим первую следующую запятую
            posEnd = StringFind(p_params, ",");
         }
         // Всё между двумя найденными позициями берём в качестве результата
         string res = StringSubstr(p_params, 0 + quoted, posEnd);
         // Убираем возвращаемую часть вместе с кавычками из строки инициализации
         p_params = StringSubstr(p_params, posEnd + quoted + 1);
         if(p_params == "") {
            p_params = NULL;
         }
         // Возвращаем результат
         return res;
      }
   }

// Иначе устанавливаем текущий объект в неисправное состояние и сообщаем об ошибке
   SetInvalid(__FUNCTION__, StringFormat("Expected String in Params:\n%s", p_params));

   return NULL;
}

//+------------------------------------------------------------------+
//| Чтение числа из строки инициализации в виде строки               |
//+------------------------------------------------------------------+
string CFactorable::ReadNumber(string &p_params) {
// Если строка инициализации не пустая и текущий объект ещё в исправном состоянии
   if(CheckTrimParams(p_params)) {
      // Если это не описание массива, не описание строки и не описание объекта
      if(p_params[0] != '['
            && p_params[0] != '"'
            && !IsObject(p_params)) {
         // Находим позицию окончания читаемого числа по следующей запятой
         int posEnd = StringFind(p_params, ",");
         // Всё от начала до найденной позиции берём в качестве результата
         string res = StringSubstr(p_params, 0, posEnd);
         // Убираем возвращаемую часть из строки инициализации
         p_params = StringSubstr(p_params, posEnd + 1);
         if(posEnd == -1) {
            p_params = NULL;
         }
         // Возвращаем результат
         return res;
      }
   }

// Иначе устанавливаем текущий объект в неисправное состояние и сообщаем об ошибке
   SetInvalid(__FUNCTION__, StringFormat("Expected Number in Params:\n%s", p_params));

   return NULL;
}

//+------------------------------------------------------------------+
//| Чтение вещественного числа из строки инициализации               |
//+------------------------------------------------------------------+
double CFactorable::ReadDouble(string &p_params) {
   return StringToDouble(ReadNumber(p_params));
}

//+------------------------------------------------------------------+
//| Чтение целого числа из строки инициализации                      |
//+------------------------------------------------------------------+
long CFactorable::ReadLong(string &p_params) {
   return StringToInteger(ReadNumber(p_params));
}

//+------------------------------------------------------------------+
//| Вычисление MD5-хеша строки                                       |
//+------------------------------------------------------------------+
string CFactorable::Hash(string p_params, string p_delimeter = "") {
   uchar hash[], key[], data[];

// Вычисляем хеш от строки инициализации
   StringToCharArray(p_params, data);
   CryptEncode(CRYPT_HASH_MD5, data, key, hash);

// Переводим его из массива чисел в строку с шестнадцатеричной записью
   string res = "";
   FOREACH(hash) {
      res += StringFormat("%X", hash[i]);
      if(i % 4 == 3 && i < 15) res += p_delimeter;
   }

   return res;
}

//+------------------------------------------------------------------+
//| Создание объекта из строки инициализации                         |
//+------------------------------------------------------------------+
CFactorable* CFactorable::Create(string p_params) {
// Указатель на создаваемый объект
   CFactorable* object = NULL;

// Читаем имя класса объекта
   string className = CFactorable::ReadClassName(p_params);

// В зависимости от имени класса находим и вызываем соответствующий конструктор
   int i;
   SEARCH(CFactorableCreator::creators, className == CFactorableCreator::creators[i].m_className, i);
   if(i != -1) {
      object = CFactorableCreator::creators[i].m_creator(p_params);
   }

// Если объект не создан или создан в неисправном состоянии, то сообщаем об ошибке
   if(!object) {
      PrintFormat(__FUNCTION__" | ERROR: Constructor not found for:\n%s",
                  p_params);
   } else if(!object.IsValid()) {
      PrintFormat(__FUNCTION__
                  " | ERROR: Created object is invalid for:\n%s",
                  p_params);
      delete object; // Удаляем неисправный объект
      object = NULL;
   }

   return object;
}
//+------------------------------------------------------------------+
