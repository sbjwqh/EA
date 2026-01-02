//+------------------------------------------------------------------+
//|                                                  ExpertState.mqh |
//|                                     Copyright 2019, Mike Antekov |
//|                                                antekov.yandex.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Mike Antekov"
#property link      "antekov.yandex.ru"
#property version   "1.00"

enum ENUM_TRAILING_STAGE {
   TS_INACTIVE,
   TS_WAIT_LEVEL,
   TS_TRAIL_LEVEL,
   TS_REACHED_LEVEL
};

class CTrailing {
private:
   ENUM_TRAILING_STAGE m_stage;
   string            m_name;
   double            m_valueOpen;
   double            m_trailOpen;
   double            m_trailStep;
   double            m_trailOpenLevel;
   bool              m_isOpen;
   int               m_sign;

   int               waitLevel(double value);
   int               trailLevel(double value);
public:
   CTrailing() : m_stage(TS_INACTIVE) {}
   ~CTrailing() {}
   void              Init(double p_valueOpen,
                          double p_trailOpen,
                          int p_sign, string p_name = "",
                          double p_trailStep = 1);
   void Deinit() {
      m_stage = TS_INACTIVE;
   }
   int               Process(double value);
   double            Level() {
      return m_trailOpenLevel;
   }
   bool IsInactive() {
      return m_stage == TS_INACTIVE;
   }
   ENUM_TRAILING_STAGE Stage() {
      return m_stage;
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTrailing::Init(double p_valueOpen, double p_trailOpen, int p_sign = 1, string p_name = "", double p_trailStep = 1) {
   m_name = p_name;
   m_valueOpen = p_valueOpen;
   m_trailOpen = p_trailOpen;
   m_sign = p_sign;
   m_trailStep = p_trailStep;
   m_stage = TS_WAIT_LEVEL;
   PrintFormat(__FUNCTION__ + ": INIT TRAIL %s (value %s %.0f) | %.0f",
                     m_name, (m_sign > 0 ? ">" : "<"), m_valueOpen, m_trailOpen);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTrailing::Process(double value) {
   if(m_stage == TS_WAIT_LEVEL) {
      return waitLevel(value);
   }

   if(m_stage == TS_TRAIL_LEVEL) {
      return trailLevel(value);
   }

   return 1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTrailing::waitLevel(double value) {
   if (m_sign > 0) {
      if (value > m_valueOpen) {
         m_stage = TS_TRAIL_LEVEL;
         m_trailOpenLevel = value - m_trailOpen;
         PrintFormat(__FUNCTION__ + ": SET TRAIL %s: %.0f | %.0f > %.0f",
                     m_name, m_trailOpenLevel, value, m_valueOpen);
      }
   } else {
      if (value < m_valueOpen) {
         m_stage = TS_TRAIL_LEVEL;
         m_trailOpenLevel = value + m_trailOpen;
         PrintFormat(__FUNCTION__ + ": SET TRAIL %s: %.0f | %.0f < %.0f",
                     m_name, m_trailOpenLevel, value, m_valueOpen);
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTrailing::trailLevel(double value) {
   if(m_sign > 0) {
      if(value < m_trailOpenLevel) {
         m_stage = TS_REACHED_LEVEL;
         m_trailOpenLevel = value;
         PrintFormat(__FUNCTION__ + ": FIRED TRAIL %s: %.0f | %.0f < %.0f",
                     m_name, m_trailOpenLevel, value, m_trailOpenLevel);
         return 1;
      }

      if (value > m_trailOpenLevel + m_trailOpen + m_trailStep) {
         PrintFormat(__FUNCTION__ + ": MOVE TRAIL %s: %.0f -> %.0f | %.0f > %.0f",
                     m_name, m_trailOpenLevel, value - m_trailOpen,
                     value, m_trailOpenLevel + m_trailOpen + m_trailStep);
         m_trailOpenLevel = value - m_trailOpen;

      }
   } else {
      if(value > m_trailOpenLevel) {
         m_stage = TS_REACHED_LEVEL;
         m_trailOpenLevel = value;
         PrintFormat(__FUNCTION__ + ": FIRED TRAIL %s: %.0f | %.0f > %.0f",
                     m_name, m_trailOpenLevel, value, m_trailOpenLevel);
         return 1;
      }

      if (value < m_trailOpenLevel - m_trailOpen - m_trailStep) {
         PrintFormat(__FUNCTION__ + ": MOVE TRAIL %s: %.0f -> %.0f | %.0f < %.0f",
                     m_name, m_trailOpenLevel, value + m_trailOpen,
                     value, m_trailOpenLevel - m_trailOpen - m_trailStep);
         m_trailOpenLevel = value + m_trailOpen;
      }
   }

   return 0;
}
//+------------------------------------------------------------------+
