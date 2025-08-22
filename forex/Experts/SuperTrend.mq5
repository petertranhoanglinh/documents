//+------------------------------------------------------------------+
//|                                               Half Trend New.mq5 |
//|                              Copyright © 2021, Vladimir Karputov |
//|                     https://www.mql5.com/ru/market/product/43161 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2021, Vladimir Karputov"
#property link      "https://www.mql5.com/ru/market/product/43161"
#property version   "1.011"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   3
//--- plot Line
#property indicator_label1  "Line"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrOrangeRed,clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
//--- plot Up
#property indicator_label2  "Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDeepSkyBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot Down
#property indicator_label3  "Down"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- input parameters
input int         InpAmplitude   = 5;     // Amplitude
input group    "Arrow"
input uchar       InpCodeUpArrow = 233;   // Arrow code for 'UpArrow' (font Wingdings)
input uchar       InpCodeDnArrow = 234;   // Arrow code for 'DnArrow' (font Wingdings)
input int         InpShift       = 10;    // Vertical shift of arrows in pixel

//Forex-Station copy & paste code; Button code start 11
input string             button_note1          = "------------------------------";
input int                btn_Subwindow         = 0;                 // What window to put the button on
input ENUM_BASE_CORNER   btn_corner            = CORNER_LEFT_UPPER; // button corner on chart for anchoring
input string             btn_text              = "HALF";              // a button name
input string             btn_Font              = "Arial";           // button font name
input int                btn_FontSize          = 9;                 // button font size
input color              btn_text_ON_color     = clrLime;           // ON color when the button is turned on
input color              btn_text_OFF_color    = clrRed;            // OFF color when the button is turned off
input color              btn_background_color  = clrDimGray;        // background color of the button
input color              btn_border_color      = clrBlack;          // border color the button
input int                button_x              = 20;                // x coordinate of the button
input int                button_y              = 25;                // y coordinate of the button
input int                btn_Width             = 80;                // button width
input int                btn_Height            = 20;                // button height
input string             soundBT               = "tick.wav";        // sound file when the button is pressed
input string             UniqueButtonID        = "HalfTrendNew";   // Unique ID for each button                         
input string             button_note2          = "------------------------------";

bool show_data = true, recalc = true;
string IndicatorName, IndicatorObjPrefix, buttonId;
//Forex-Station copy & paste code; Button code end 11


//--- indicator buffers
double   LineBuffer[],LineColors[],UpBuffer[],DownBuffer[],HighestBuffer[],LowestBuffer[],MA_PRICE_HIGH_Buffer[],MA_PRICE_LOW_Buffer[];
//---
int      handle_iMA_PRICE_HIGH;              // variable for storing the handle of the iMA indicator
int      handle_iMA_PRICE_LOW;               // variable for storing the handle of the iMA indicator
int      bars_calculated            = 0;
int      m_start_bar                = 0;     // start bar
bool     m_init_error               = false; // error on InInit 
//+------------------------------------------------------------------+
//Forex-Station copy & paste code; Button code start 12
string GenerateIndicatorName(const string target)
   {
    string name = target;
    int try     = 2;
    while(ChartWindowFind(0, name) != -1)
        name = target + " #" + IntegerToString(try++);
    return name;
   }
//+------------------------------------------------------------------+
int OnInit(void)
   {
    IndicatorName = GenerateIndicatorName(btn_text);
    IndicatorObjPrefix = "__" + IndicatorName + "__";
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    double ForexVal;
    if(GlobalVariableGet(IndicatorName + "_visibility", ForexVal))
        show_data = ForexVal != 0;
        
    ChartSetInteger(ChartID(), CHART_EVENT_MOUSE_MOVE, 1);
    buttonId = IndicatorObjPrefix + UniqueButtonID;
    createButton(buttonId, btn_text, btn_Width, btn_Height, btn_Font, btn_FontSize, btn_background_color, btn_border_color, btn_text_ON_color);
    ObjectSetInteger(ChartID(), buttonId, OBJPROP_YDISTANCE, button_y);
    ObjectSetInteger(ChartID(), buttonId, OBJPROP_XDISTANCE, button_x);

    Init2();
    return(INIT_SUCCEEDED);
   }
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { 
   if(handle_iMA_PRICE_HIGH!=INVALID_HANDLE)
      IndicatorRelease(handle_iMA_PRICE_HIGH);
   if(handle_iMA_PRICE_LOW!=INVALID_HANDLE)
      IndicatorRelease(handle_iMA_PRICE_LOW);
     ObjectsDeleteAll(ChartID(), buttonId, -1, -1);
}
//+------------------------------------------------------------------+
void createButton(string buttonID, string buttonText, int width, int height, string font, int fontSize, color bgColor, color borderColor, color txtColor)
   {
    ObjectDelete    (ChartID(), buttonID);
    ObjectCreate    (ChartID(), buttonID, OBJ_BUTTON, btn_Subwindow, 0, 0);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_COLOR, txtColor);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_BORDER_COLOR, borderColor);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_BORDER_TYPE, BORDER_RAISED);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_XSIZE, width);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_YSIZE, height);
    ObjectSetString (ChartID(), buttonID, OBJPROP_FONT, font);
    ObjectSetString (ChartID(), buttonID, OBJPROP_TEXT, buttonText);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_SELECTABLE, 0);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_CORNER, btn_corner);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_HIDDEN, 1);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_XDISTANCE, 9999);
    ObjectSetInteger(ChartID(), buttonID, OBJPROP_YDISTANCE, 9999);
   }
//+------------------------------------------------------------------------------------------------------------------+
void handleButtonClicks()
   {
    if(ObjectGetInteger(ChartID(), buttonId, OBJPROP_STATE))
       {
        ObjectSetInteger(ChartID(), buttonId, OBJPROP_STATE, false);
        show_data = !show_data;
        GlobalVariableSet(IndicatorName + "_visibility", show_data ? 1.0 : 0.0);
        recalc = true;
       }
   }
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
   {
    handleButtonClicks();
    bool ForexStation = ObjectGetInteger(ChartID(),sparam,OBJPROP_TYPE);
    if (id==CHARTEVENT_OBJECT_CLICK && ForexStation==OBJ_BUTTON)
    {
      if (soundBT!="") PlaySound(soundBT);     
    }

    if (show_data)
       {
        ObjectSetInteger(ChartID(),buttonId,OBJPROP_COLOR,btn_text_ON_color);           
        PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
        PlotIndexSetInteger(1, PLOT_DRAW_TYPE,DRAW_ARROW);
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE,DRAW_ARROW);
        PlotIndexSetInteger(1, PLOT_ARROW,InpCodeUpArrow);
        PlotIndexSetInteger(2, PLOT_ARROW,InpCodeDnArrow);
       }
    else
       {
        ObjectSetInteger(ChartID(),buttonId,OBJPROP_COLOR,btn_text_OFF_color);
        PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
       }
   }
//+------------------------------------------------------------------+
//Forex-Station copy & paste code; Button code end 12
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int Init2()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,LineBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,LineColors,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,UpBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,DownBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,HighestBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,LowestBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,MA_PRICE_HIGH_Buffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,MA_PRICE_LOW_Buffer,INDICATOR_CALCULATIONS);

//--- setting a code from the Wingdings charset as the property of PLOT_ARROW
   PlotIndexSetInteger(1,PLOT_ARROW,InpCodeUpArrow);
   PlotIndexSetInteger(2,PLOT_ARROW,InpCodeDnArrow);
//--- set the vertical shift of arrows in pixels
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,InpShift);
   PlotIndexSetInteger(2,PLOT_ARROW_SHIFT,-InpShift);
//--- set as an empty value 0
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0.0);
//--- create handle of the indicator iMA
   handle_iMA_PRICE_HIGH=iMA(Symbol(),Period(),InpAmplitude,0,MODE_SMA,PRICE_HIGH);
//--- if the handle is not created
   if(handle_iMA_PRICE_HIGH==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iMA ('High') indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      m_init_error=true;
      return(INIT_SUCCEEDED);
     }
//--- create handle of the indicator iMA
   handle_iMA_PRICE_LOW=iMA(Symbol(),Period(),InpAmplitude,0,MODE_SMA,PRICE_LOW);
//--- if the handle is not created
   if(handle_iMA_PRICE_LOW==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iMA ('Low') indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early
      m_init_error=true;
      return(INIT_SUCCEEDED);
     }
//---
   m_start_bar=(InpAmplitude>m_start_bar)?InpAmplitude:m_start_bar;
   m_start_bar++;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(m_init_error)
      return(0);
//--- number of values copied from indicators
   int values_to_copy;
//--- determine the number of values calculated in the indicator
   int calculated_ma_high=BarsCalculated(handle_iMA_PRICE_HIGH);
   if(calculated_ma_high<=0)
     {
      PrintFormat("BarsCalculated(handle_iMA_PRICE_HIGH) returned %d, error code %d",calculated_ma_high,GetLastError());
      return(0);
     }
//--- determine the number of values calculated in the indicator
   int calculated_ma_low=BarsCalculated(handle_iMA_PRICE_LOW);
   if(calculated_ma_low<=0)
     {
      PrintFormat("BarsCalculated(handle_iMA_PRICE_LOW) returned %d, error code %d",calculated_ma_low,GetLastError());
      return(0);
     }
   if(calculated_ma_high!=calculated_ma_low)
     {
      PrintFormat("BarsCalculated(handle_iMA_PRICE_HIGH) returned %d, BarsCalculated(handle_iMA_PRICE_LOW) returned %d",calculated_ma_high,calculated_ma_low);
      return(0);
     }
   int calculated=calculated_ma_high;
//--- if it is the first start of calculation of the indicator or if the number of values in the iMA indicator changed
//---or if it is necessary to calculated the indicator for two or more bars (it means something has changed in the price history)
   if(prev_calculated==0 || calculated!=bars_calculated || rates_total>prev_calculated+1)
     {
      //--- if the iMABuffer array is greater than the number of values in the iMA indicator for symbol/period, then we don't copy everything
      //--- otherwise, we copy less than the size of indicator buffers
      if(calculated>rates_total)
         values_to_copy=rates_total;
      else
         values_to_copy=calculated;
     }
   else
     {
      //--- it means that it's not the first time of the indicator calculation, and since the last call of OnCalculate()
      //--- for calculation not more than one bar is added
      values_to_copy=(rates_total-prev_calculated)+1;
     }
//--- fill array with values of the Moving Average indicator
//--- if FillArrayFromBuffer returns false, it means the information is nor ready yet, quit operation
   if(!FillArrayFromBuffer(MA_PRICE_HIGH_Buffer,0,handle_iMA_PRICE_HIGH,values_to_copy))
      return(0);
   if(!FillArrayFromBuffer(MA_PRICE_LOW_Buffer,0,handle_iMA_PRICE_LOW,values_to_copy))
      return(0);
//--- memorize the number of values in the Moving Average indicator
   bars_calculated=calculated;
//--- main loop
   int limit=prev_calculated-1;
   if(prev_calculated==0)
     {
      limit=m_start_bar;
      for(int i=0; i<limit; i++)
        {
         LineBuffer[i]=high[i];
         LineColors[i]=0.0;
         UpBuffer[i]=0.0;
         DownBuffer[i]=0.0;
         HighestBuffer[i]=high[i];
         LowestBuffer[i]=low[i];
        }
      double highest=high[ArrayMaximum(high,limit-InpAmplitude+1,InpAmplitude)];
      double lowest =low[ArrayMinimum(low,limit-InpAmplitude+1,InpAmplitude)];
      HighestBuffer[limit]=highest;
      LowestBuffer[limit]=lowest;
     }
   for(int i=limit; i<rates_total; i++)
     {
      double highest=high[ArrayMaximum(high,i-InpAmplitude+1,InpAmplitude)];
      double lowest =low[ArrayMinimum(low,i-InpAmplitude+1,InpAmplitude)];
      //---
      HighestBuffer[i]=highest;
      LowestBuffer[i]=lowest;
      //---
      UpBuffer[i]=0.0;
      DownBuffer[i]=0.0;
      //---
      if(MA_PRICE_HIGH_Buffer[i]<LineBuffer[i-1] && MA_PRICE_LOW_Buffer[i]<LineBuffer[i-1] && HighestBuffer[i]<LineBuffer[i-1])
        {
         LineBuffer[i]=HighestBuffer[i];
         LineColors[i]=LineColors[i-1];
         if(LineBuffer[i]<LineBuffer[i-1])
            LineColors[i]=0.0;
         if(LineBuffer[i]>LineBuffer[i-1])
            LineColors[i]=1.0;
         if(LineColors[i-1]==0.0 && LineColors[i]==1.0)
            UpBuffer[i]=LineBuffer[i-1];
         if(LineColors[i-1]==1.0 && LineColors[i]==0.0)
            DownBuffer[i]=LineBuffer[i-1];
         continue;
        }
      if(MA_PRICE_HIGH_Buffer[i]>LineBuffer[i-1] && MA_PRICE_LOW_Buffer[i]>LineBuffer[i-1] && LowestBuffer[i]>LineBuffer[i-1])
        {
         LineBuffer[i]=LowestBuffer[i];
         LineColors[i]=LineColors[i-1];
         if(LineBuffer[i]<LineBuffer[i-1])
            LineColors[i]=0.0;
         if(LineBuffer[i]>LineBuffer[i-1])
            LineColors[i]=1.0;
         if(LineColors[i-1]==0.0 && LineColors[i]==1.0)
            UpBuffer[i]=LineBuffer[i-1];
         if(LineColors[i-1]==1.0 && LineColors[i]==0.0)
            DownBuffer[i]=LineBuffer[i-1];
         continue;
        }
      LineBuffer[i]=LineBuffer[i-1];
      LineColors[i]=LineColors[i-1];
      continue;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Filling indicator buffers from the MA indicator                  |
//+------------------------------------------------------------------+
bool FillArrayFromBuffer(double &values[],   // indicator buffer of Moving Average values
                         int shift,          // shift
                         int ind_handle,     // handle of the iMA indicator
                         int amount          // number of copied values
                        )
  {
//--- reset error code
   ResetLastError();
//--- fill a part of the iMABuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(ind_handle,0,-shift,amount,values)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iMA indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
//--- everything is fine
   return(true);
  }
//+------------------------------------------------------------------+
//| Filling indicator buffers from the ATR indicator                 |
//+------------------------------------------------------------------+
bool FillArrayFromBuffer(double &values[],  // indicator buffer for ATR values
                         int ind_handle,    // handle of the iATR indicator
                         int amount         // number of copied values
                        )
  {
//--- reset error code
   ResetLastError();
//--- fill a part of the iATRBuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(ind_handle,0,0,amount,values)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iATR indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
//--- everything is fine
   return(true);
  }
//+------------------------------------------------------------------+
