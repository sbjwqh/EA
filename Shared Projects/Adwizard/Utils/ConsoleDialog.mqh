//+------------------------------------------------------------------+
//|                                                ConsoleDialog.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.02"

#include "../Utils/Macros.mqh"
#include <Canvas/Canvas.mqh>
#include <Controls/Dialog.mqh>

#define DIALOG_VERTICAL_MARGIN (17) // Отступ верхнего края диалогового окна от края графика

//+------------------------------------------------------------------+
//| Класс диалогового окна на весь экран                             |
//| для вывода многострочного текста                                 |
//+------------------------------------------------------------------+
class CConsoleDialog : public CAppDialog {
protected:
   CCanvas           m_canvas;         // Объект холста для вывода текста

   string            m_lines[];        // Массив строк текста
   string            m_text;           // Текст для вывода в диалоговом окне

   int               m_startRow;       // Начальная строка видимого текста
   int               m_startCol;       // Начальный столбец (символ) видимого текста

   int               m_totalRows;      // Общее число строк текста
   int               m_totalCols;      // Общее число символов в самой длинной строке текста

   int               m_visibleRows;    // Максимальное количество видимых строк
   int               m_visibleCols;    // Максимальное количество видимых символов в строке

   string            m_fontName;          // Название шрифта для текста
   int               m_fontSize;          // Размер шрифта
   uint              m_fontColor;         // Цвет шрифта

   int               m_fontSymbolWidth;   // Ширина одного символа в пикселях
   int               m_fontSymbolHeight;  // Высота строки текста в пикселях

   uint              m_backgroundColor;   // Цвет фона

   bool              m_mouseWheel;        // Предыдущее состояние отслеживания событий прокрутки мышью

   bool              CreateCanvas();      // Создание холста
   void              UpdateCanvas();      // Вывод текста на холсте
   void              UpdateCanvasFont();  // Изменение шрифта холста

public:
                     CConsoleDialog();       // Конструктор
                    ~CConsoleDialog(void);   // Деструктор

   // Методы создания диалогового окна
   bool              Create(string name);
   virtual bool      Create(const long chart, const string name, const int subwin,
                            const int x1, const int y1, const int x2, const int y2);
   // Обработка событий
   virtual void      ChartEvent(const int id, const long &lparam,
                                const double &dparam, const string &sparam);

   virtual void      Minimize();             // Минимизация диалогового окна
   virtual void      Maximize();             // Максимизация диалогового окна

   virtual void      Text(string text);      // Установка нового текста

   virtual void      FontName(string p_fontName);  // Установка названия шрифта
   virtual bool      FontSize(int p_fontSize);     // Установка размера шрифта
   virtual void      FontColor(uint p_fontColor);  // Установка цвета шрифта

   // Установка цвета фона
   virtual void      BackgroundColor(uint p_backgroundColor);
};


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CConsoleDialog::CConsoleDialog() :
   m_fontName("Consolas"),
   m_fontSize(13),
   m_fontColor(ColorToARGB(clrBlack, 240)),
   m_backgroundColor(ColorToARGB(clrBlack, 0)) {
   FontSize(m_fontSize);
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CConsoleDialog::~CConsoleDialog() {   
// Удаляем холст
   m_canvas.Destroy();

// Возвращаем прежнюю настройку обработки событий прокрутки мышью
   ChartSetInteger(m_chart_id, CHART_EVENT_MOUSE_WHEEL, (long)m_mouseWheel);
   
// Отвязываем график, чтобы он не закрылся
   m_chart.Detach();
}

//+------------------------------------------------------------------+
//| Метод создания диалогового окна только по имени                  |
//+------------------------------------------------------------------+
bool CConsoleDialog::Create(string name) {
// Устанавливаем положение угла и размеры окна
   int x1 = 0;
   int y1 = DIALOG_VERTICAL_MARGIN;
   int y2 = (int) ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int x2 = (int) ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

// Вызываем метод создания по заданным размерам
   return Create(0, name, 0, x1, y1, x2, y2);
}

//+------------------------------------------------------------------+
//| Метод создания диалогового окна                                  |
//+------------------------------------------------------------------+
bool CConsoleDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2) {
// Вызов родительского метода создания диалога
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2)) {
      return false;
   }

// Устновка размеров минимизированного окна диалога
   m_min_rect.SetBound(0, DIALOG_VERTICAL_MARGIN,
                       250, DIALOG_VERTICAL_MARGIN + CONTROLS_DIALOG_MINIMIZE_HEIGHT);

// Создание холста
   if(!CreateCanvas()) {
      return false;
   }

// Запоминаем прежнюю настройку обработки событий прокрутки мышью
   m_mouseWheel = ChartGetInteger(0, CHART_EVENT_MOUSE_WHEEL);

// Устанавливаем отслеживание событий прокрутки мышью
   ChartSetInteger(chart, CHART_EVENT_MOUSE_WHEEL, 1);

// Устанавливаем начальное положение текста в окне
   m_startRow = 0;
   m_startCol = 0;

   return true;
}

//+------------------------------------------------------------------+
//| Обработка событий                                                |
//+------------------------------------------------------------------+
void CConsoleDialog::ChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
// Обработка события прокрутки колёсика мыши
   if(id == CHARTEVENT_MOUSE_WHEEL) {
      // Если окно диалога минимизировано, то не обрабатываем это событие
      if(m_minimized) {
         return;
      }

      // Разбираем состояние кнопок и колесика мышки для этого события
      int flg_keys = (int)(lparam >> 32);       // флаг состояний клавиш Ctrl, Shift и кнопок мышки
      int delta    = (int)dparam;               // суммарное значение прокрутки колесика,
      // срабатывает при достижении +120 или -120

      // Если нажата клавиша SHIFT, то
      if((flg_keys & 0x0004) != 0) {
         // Если количество символов в строке больше количества видимых
         // символов в диалоге, то выполняем горизонтальное смещение
         if(m_totalCols > m_visibleCols) {
            // На одно событие прокрутки будем смещаться на 2 символа (120 / 60 = 2)
            delta /= 60;

            // Если новая начальная позиция попадает в допустимый диапазон, то
            if(m_startCol - delta >= 0
                  && m_startCol - delta <= m_totalCols - m_visibleCols + 2) {
               // Запоминаем новую начальную позицию
               m_startCol -= delta;

               // Обновляем холст
               UpdateCanvas();
            }
         }
      } else if (flg_keys == 0) {
         // Иначе если количество строк текста больше количества видимых
         // строк в диалоге, то выполняем вертикальное смещение
         if(m_totalRows > m_visibleRows) {
            // На одно событие прокрутки будем смещаться на 1 строку (120 / 120 = 1)
            delta /= 120;

            // Если новая начальная позиция попадает в допустимый диапазон, то
            if(m_startRow - delta >= 0
                  && m_startRow - delta <= m_totalRows - m_visibleRows + 1) {
               // Запоминаем новую начальную позицию
               m_startRow -= delta;

               // Обновляем холст
               UpdateCanvas();
            }
         }
      } else if((flg_keys & 0x0008) != 0) {
         // Иначе если нажата клавиша CTRL, то пробуем установить новый размер шрифта
         if(FontSize(m_fontSize + delta / 120)) {
            // Обновляем холст
            UpdateCanvas();
         }
      }

      return;
   }

// Обработка события изменения графика
   if(id == CHARTEVENT_CHART_CHANGE) {
      // Если размеры отображаемой области изменились
      if(m_chart.HeightInPixels(m_subwin) != Height() + DIALOG_VERTICAL_MARGIN
            || m_chart.WidthInPixels() != Width()) {
         // Установить для диалогового окна новые размеры
         m_norm_rect.SetBound(0, DIALOG_VERTICAL_MARGIN, m_chart.WidthInPixels(), m_chart.HeightInPixels(m_subwin));

         // Если окно диалога не минимизировано, то
         if(!m_minimized) {
            // Разворачивем его на полный экран графика с новыми размерами
            Maximize();
         }
         return;
      }
   }

// Обработка отсальных событий в вышестоящем классе
   CAppDialog::ChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Минмизация диалогового окна                                      |
//+------------------------------------------------------------------+
void CConsoleDialog::Minimize() {
// Удаляем холст
   m_canvas.Destroy();

// Вызываем родительский метод минимизации
   CAppDialog::Minimize();
}

//+------------------------------------------------------------------+
//| Максимизация диалогового окна                                    |
//+------------------------------------------------------------------+
void CConsoleDialog::Maximize() {
// Вызываем родительский метод максимизации
   CAppDialog::Maximize();

// Создаём холст
   CreateCanvas();

// Выводим текст на холсте
   UpdateCanvas();
}

//+------------------------------------------------------------------+
//| Установка текста                                                 |
//+------------------------------------------------------------------+
void CConsoleDialog::Text(string text) {
// Если текст изменяется, то
   if(text != m_text) {
      // Запомним новый тект
      m_text = text;

      // Делим текст на строки
      StringSplit(m_text, '\n', m_lines);

      // Запоминаем количество строк
      m_totalRows = ArraySize(m_lines);

      // Определяем максимальную длину строк
      m_totalCols = 0;
      FOREACH(m_lines) {
         m_totalCols = MathMax(m_totalCols, StringLen(m_lines[i]));
      }

      // Выводим текст на холсте
      UpdateCanvas();
   }
}

//+------------------------------------------------------------------+
//| Установка названия шрифта                                        |
//+------------------------------------------------------------------+
void CConsoleDialog::FontName(string p_fontName) {
// Запоминаем новое имя шрифта
   m_fontName = p_fontName;

// Обновляем шрифт холста
   UpdateCanvasFont();
}

//+------------------------------------------------------------------+
//| Установка размера шрифта                                         |
//+------------------------------------------------------------------+
bool CConsoleDialog::FontSize(int p_fontSize) {
// Если размер находится в разумных пределах, то
   if (p_fontSize >= 8 && p_fontSize <= 72) {
      // Запоминаем новый размер шрифта
      m_fontSize = p_fontSize;

      // Сбрасываем начальную строку и столбец
      m_startRow = 0;
      m_startCol = 0;

      // Обновляем шрифт холста
      UpdateCanvasFont();

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Установка цвета шрифта                                           |
//+------------------------------------------------------------------+
void CConsoleDialog::FontColor(uint p_fontColor) {
   m_fontColor = p_fontColor;
}

//+------------------------------------------------------------------+
//| Установка цвета фона                                             |
//+------------------------------------------------------------------+
void CConsoleDialog::BackgroundColor(uint p_backgroundColor) {
   m_backgroundColor = p_backgroundColor;
}

//+------------------------------------------------------------------+
//| Создание холста                                                  |
//+------------------------------------------------------------------+
bool CConsoleDialog::CreateCanvas() {
// Получаем размеры клиентской области диалогового окна
   int height = ClientAreaHeight();
   int width = ClientAreaWidth();

// Если размеры ненулевые
   if(height > 0 && width > 0) {
      // Если при создании холста возникла ошибка, то выходим
      if(!m_canvas.CreateBitmapLabel("display",
                                     ClientAreaLeft(),
                                     ClientAreaTop(),
                                     ClientAreaWidth(),
                                     ClientAreaHeight(),
                                     COLOR_FORMAT_ARGB_NORMALIZE)) {
         PrintFormat(__FUNCTION__" | ERROR: Creating canvas %d", GetLastError());
         return false;
      }

      UpdateCanvasFont();
   }

   return true;
}

//+------------------------------------------------------------------+
//| Вывод текста на холсте                                           |
//+------------------------------------------------------------------+
void CConsoleDialog::UpdateCanvas() {
// Стираем холст цветом фона
   m_canvas.Erase(m_backgroundColor);

// Для каждой строки, попадающей в видимый диапазон
   for (int i = m_startRow; i < MathMin(m_totalRows, m_startRow + m_visibleRows); i++) {
      // Берём очередную строку текста
      string line = m_lines[i];

      // Если её надо показывать не с первого символа, то
      if (m_startCol > 0) {
         // Вырезаем начальные символы
         line = StringSubstr(line, m_startCol);
      }

      // Выводим строку на холст
      m_canvas.TextOut(5, 5 + (i - m_startRow) * m_fontSymbolHeight, line, m_fontColor, TA_LEFT | TA_TOP);
   }
   
   if(MQLInfoInteger(MQL_TESTER) && MQLInfoInteger(MQL_VISUAL_MODE)) {
      ObjectsDeleteAll(m_chart_id, "#");
   }

// Вызываем метод отрисовки холста на экране
   m_canvas.Update(true);
   
   
}


//+------------------------------------------------------------------+
//| Изменение шрифта холста                                          |
//+------------------------------------------------------------------+
void CConsoleDialog::UpdateCanvasFont() {
// Установка параметров шрифта для вывода текста на холст
   m_canvas.FontSet(m_fontName, m_fontSize);

// Установка новых размеров одного символа
   m_canvas.TextSize("M", m_fontSymbolWidth, m_fontSymbolHeight);

// Определяем количество видимых строк и символов в строке (столбцов)
   m_visibleRows = ClientAreaHeight() / m_fontSymbolHeight;
   m_visibleCols = ClientAreaWidth() / m_fontSymbolWidth;
}
//+------------------------------------------------------------------+
