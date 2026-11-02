//+------------------------------------------------------------------+
//|                                                Vortex Pro MA.mq5 |
//|                                     Copyright 2026, Neto Queiroz |
//|           https://github.com/luizernestoqueiroz/mql5-indicators/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Neto Queiroz"
#property link      "https://github.com/luizernestoqueiroz/mql5-indicators/"
#property version   "1.00"
//+------------------------------------------------------------------+

#property indicator_separate_window

#property indicator_buffers 9
#property indicator_plots   3

//--- Plot 0: Filling between Vortex Pro and the center level
#property indicator_label1  "Vortex Zone Fill"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'31,58,34',C'63,28,28'

//--- Plot 1: Main Line
#property indicator_label2  "Vortex Pro"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrDodgerBlue,clrRed
#property indicator_width2  2

//--- Plot 2: Moving Average
#property indicator_label3  "Vortex Pro MA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  1

//--- Level 0
#property indicator_level1  0.0
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_SOLID

//+------------------------------------------------------------------+

enum ENUM_VP_MA { VP_EMA, VP_SMA, VP_HMA, VP_WMA };

input int        InpLength   = 14;     // Vortex Period
input int        InpMALength = 9;      // MA Period
input ENUM_VP_MA InpMAType   = VP_EMA; // MA Type

//+------------------------------------------------------------------+

double BufFillA[];   // Vortex Pro (fill)
double BufFillB[];   // zero (fill)
double BufVortex[];  // Vortex Pro
double BufColor[];   // color index
double BufMA[];      // MA
double BufVMP[];     // |high - low[1]|
double BufVMM[];     // |low - high[1]|
double BufTR[];      // true range
double BufHMA[];     // 2*WMA(n/2) - WMA(n)

int g_len, g_malen;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_len   = MathMax(2, InpLength);
   g_malen = MathMax(1, InpMALength);
   
   SetIndexBuffer(0, BufFillA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufFillB,  INDICATOR_DATA);
   SetIndexBuffer(2, BufVortex, INDICATOR_DATA);
   SetIndexBuffer(3, BufColor,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, BufMA,     INDICATOR_DATA);
   SetIndexBuffer(5, BufVMP,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufVMM,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, BufTR,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, BufHMA,    INDICATOR_CALCULATIONS);
   
   for(int p = 0; p < 3; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   for(int p = 0; p < 9; p++)
      PlotIndexSetInteger(p, PLOT_SHOW_DATA, false);
      
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, g_len);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, g_len);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, g_len);
   
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   IndicatorSetString(INDICATOR_SHORTNAME, "Vortex Pro MA");

   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
  {
   if(rates_total <= g_len)
      return(0);

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;
   const int first = g_len;
   const double alpha = 2.0 / (g_malen + 1.0);
   const int half = MathMax(1, g_malen / 2);
   const int sq   = MathMax(1, (int)MathRound(MathSqrt((double)g_malen)));

   for(int i = start; i < rates_total; i++)
     {
      BufFillA[i]  = EMPTY_VALUE;
      BufFillB[i]  = EMPTY_VALUE;
      BufVortex[i] = EMPTY_VALUE;
      BufMA[i]     = EMPTY_VALUE;
      BufHMA[i]    = EMPTY_VALUE;
      BufColor[i]  = 0;

      if(i == 0)
        {
         BufTR[i]  = high[i] - low[i];
         BufVMP[i] = 0.0;
         BufVMM[i] = 0.0;
         continue;
        }
        
      double tr = MathMax(high[i] - low[i],
                  MathMax(MathAbs(high[i] - close[i-1]), MathAbs(low[i] - close[i-1])));
      BufTR[i]  = tr;
      BufVMP[i] = MathAbs(high[i] - low[i-1]);
      BufVMM[i] = MathAbs(low[i] - high[i-1]);

      if(i < first)
         continue;

      //--- Vortex Pro
      double sp = 0.0, sm = 0.0, st = 0.0;
      
      for(int j = i - g_len + 1; j <= i; j++)
        {
         sp += BufVMP[j];
         sm += BufVMM[j];
         st += BufTR[j];
        }
        
      double v = (st > 0.0) ? (sp - sm) / st * 10.0 : 0.0;
      BufVortex[i] = v;
      BufFillA[i]  = v;
      BufFillB[i]  = 0.0;

      //--- Média móvel
      double ma = EMPTY_VALUE;
      
      switch(InpMAType)
        {
         case VP_EMA:
            if(i == first || BufMA[i-1] == EMPTY_VALUE)
               ma = v;
            else
               ma = alpha * v + (1.0 - alpha) * BufMA[i-1];
            break;

         case VP_SMA:
            if(i - g_malen + 1 >= first)
              {
               double s = 0.0;
               for(int k = i - g_malen + 1; k <= i; k++)
                  s += BufVortex[k];
               ma = s / g_malen;
              }
            break;

         case VP_WMA:
            ma = CalcWMA(BufVortex, i, g_malen, first);
            break;

         case VP_HMA:
           {
            double w1 = CalcWMA(BufVortex, i, half, first);
            double w2 = CalcWMA(BufVortex, i, g_malen, first);
            if(w1 != EMPTY_VALUE && w2 != EMPTY_VALUE)
               BufHMA[i] = 2.0 * w1 - w2;
            ma = CalcWMA(BufHMA, i, sq, first + g_malen - 1);
            break;
           }
        }
      BufMA[i] = ma;

      //--- Main Line Color Index
      if(ma != EMPTY_VALUE)
         BufColor[i] = (v >= ma) ? 0 : 1;
      else
         BufColor[i] = 0;
     }

   return(rates_total);
  }
  
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| WMA on array                                                     |
//+------------------------------------------------------------------+
double CalcWMA(const double &arr[], const int i, const int n, const int first)
  {
   if(n < 1 || i - n + 1 < first)
      return(EMPTY_VALUE);
      
   double sum = 0.0;
   
   for(int k = 0; k < n; k++)
      sum += arr[i - n + 1 + k] * (k + 1);
   
   return(sum / (n * (n + 1) / 2.0));
  }