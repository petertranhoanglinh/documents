//+------------------------------------------------------------------+
//|                                                   BotLuoi_v2.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#define MAGIC_NUMBER 12345
#define EXPERT_MAGIC 123456
#include <Trade\Trade.mqh> 

CTrade trade;
CSymbolInfo symbolInfo;

input group "[BUY] THÔNG TIN VÀO LỆNH BUY";
input group "__Cấu hình Level 1";
input int level1 = 10; // Số lệnh cho Level 1
input double volumnLv1  = 0.01; // Số lot mở lệnh
input double priceDCALv1 = 3; // Khoảng giá mua thêm 
input double takeProfitLv1 = 3; // Chốt lời với khoảng giá

input group "__Cấu hình Level 2";
input int level2 = 10; // Số lệnh cho Level 2
input double volumnLv2  = 0.01; // Số lot mở lệnh
input double priceDCALv2 = 3; // Khoảng giá mua thêm 
input double takeProfitLv2 = 3; // Chốt lời với khoảng giá

input group "__Cấu hình Level 3";
input int level3 = 10; // Số lệnh cho Level 3
input double volumnLv3  = 0.01; // Số lot mở lệnh
input double priceDCALv3 = 3; // Khoảng giá mua thêm 
input double takeProfitLv3 = 3; // Chốt lời với khoảng giá

input group "__Cấu hình Level 4";
input int level4 = 10; // Số lệnh cho Level 4
input double volumnLv4  = 0.01; // Số lot mở lệnh
input double priceDCALv4 = 3; // Khoảng giá mua thêm 
input double takeProfitLv4 = 3; // Chốt lời với khoảng giá

input group "__Cấu hình level những lệnh tiếp sau";
input double volumnLvLast = 0.01; // Số lot mở lệnh
input double priceDCALvLast = 3; // Khoảng giá mua thêm 
input double takeProfitLvLast = 3; // Chốt lời với khoảng giá

input group "[SELL] THÔNG TIN VÀO LỆNH SELL"
input group "__1 Thêm DCA SELL Nhanh Giàu"
input bool  openSellDCA  = false; // Tắt/Mở chức năng
input double volumnSell  = 0.01; // Số lot mở lệnh
input double priceDCASell = 3; // Khoảng giá mua thêm 
input double takeProfitSell = 3; // Chốt lời với khoảng giá
input int openMaxSell = 10; // Số lệnh SELL DCA tối đa
input int openTiaLenh = 10; // Kích hoạt Tỉa lệnh SELL


input group "__2 Thêm BOT SELL Hỗ Trợ Khi Âm TK"
input bool  openHedge  = true; // Tắt/Mở chức năng
input int conditonNumBuyOpen = 10; // Bắt đầu khi có số lệnh BUY đang mở
input double  volumnHedge  = 0.01; // Số lot mở lệnh
input double  priceSLTP  = 3; // Giá đặt Stoploss và Takeprofit
input double  maxVolumnSellHedge = 0.32; // Max Volumn Khi mở lệnh sell hedge

input group "[TỈA LỆNH] CẤU HÌNH TỈA LỆNH";
input bool  enableTiaLenh = true; // Bật/tắt chức năng tỉa lệnh
input int  soLenhToiThieuDeTia = 30; // Số lệnh tối thiểu để tỉa
input double maxDrawdow = 30; // drawdow tài khoản cần tỉa viết 1 -> 100

int Magic_Hedge = 111;
ulong ticketHedge = 0; 
int countOpenBuy = 0;
double ddProfit = 0;

int maHandle;
double maBuffer[];
string currentTrend = "SIDEWAY";
datetime lastCheck = 0; 
datetime trendStartTime = 0;
datetime lastCheckTiaLenh = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   paintlable();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Dọn dẹp khi kết thúc
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   updateReport(); 
   Comment(
      "⏰ Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "\n",
      "📈 Trend: ", currentTrend
   );
   
   if(TimeCurrent() - lastCheck >= 20) // check mỗi 20s
   {
      string newTrend = CheckTrend();

      // Nếu trend hiện tại là SIDEWAY -> cho đổi ngay
      if(currentTrend == "SIDEWAY")
      {
         currentTrend = newTrend;
         trendStartTime = TimeCurrent();
         drawArrow(currentTrend);
      }
      else
      {
         // Nếu trend mới khác và đã giữ trend cũ >= 3 phút
         if(newTrend != currentTrend && (TimeCurrent() - trendStartTime >= 3*60))
         {
            currentTrend = newTrend;
            trendStartTime = TimeCurrent();
            drawArrow(currentTrend);
         }
      }

      Print("Trend use check: ", currentTrend);
      Print("Trend Now: ", newTrend);
      lastCheck = TimeCurrent(); 
   }
     
   
   double minPriceBuy = DBL_MAX;
   double hightPriceBuy = 0;
   ddProfit = 0;
   
   double hightPriceSELL = 0; 
   
   int totalPositonBUY = 0;
   int totalPositonSELL = 0;
   int totalPositonHedge = 0;
   
   // Đếm các vị thế đang mở
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      ulong typePosition = PositionGetInteger(POSITION_TYPE);
      ulong positionMagic = PositionGetInteger(POSITION_MAGIC);
      double pricePosition = PositionGetDouble(POSITION_PRICE_OPEN);
      
      ddProfit += PositionGetDouble(POSITION_PROFIT);
      
      if(typePosition == POSITION_TYPE_BUY)
      {
         totalPositonBUY++; 
         if(pricePosition < minPriceBuy)
         {
            minPriceBuy = pricePosition;
         }
         if(pricePosition > hightPriceBuy)
         {
            hightPriceBuy = pricePosition;
         }
      }
      else if(EXPERT_MAGIC == positionMagic)
      {
         totalPositonSELL++; 
         if(pricePosition > hightPriceSELL)
         {
            hightPriceSELL = pricePosition;
         }
      }
      else if(Magic_Hedge == positionMagic)
      {
         totalPositonHedge++;
      }
   }
   
    
   
   
   // Handle BUY
   if(totalPositonBUY == 0)
   {
      openBuy(volumnLv1, takeProfitLv1, "Lệnh đầu tiền");
   }
   else
   {
      double priceDCA = 0; 
      double volumn = 0; 
      double takeprofit = 0; 
      double spacePriceBUY = minPriceBuy - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      getValuePosition(totalPositonBUY, priceDCA, volumn, takeprofit);
      
      if(spacePriceBUY > priceDCA) 
      {
         openBuy(volumn, takeprofit, "BUY|" + IntegerToString(totalPositonBUY) + "|");
      }
   } 
   
   // Handle SELL DCA 
   if(openSellDCA == true && totalPositonSELL < openMaxSell)
   {
      double spacePriceSELL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - hightPriceSELL;
      if(totalPositonSELL == 0)
      {
         openSELL("Lệnh đầu tiền");
      }
      else if(spacePriceSELL > priceDCASell)
      {
         openSELL("SELL|" + IntegerToString(totalPositonSELL) + "|");
      }
   }
   
   // Handle SELL HEDGE
   if(openHedge == true && totalPositonHedge == 0 && currentTrend != "UP_STRONG" && currentTrend != "UP_WEAK")
   {
      if(ticketHedge == 0)
      {
         if(totalPositonBUY > conditonNumBuyOpen)
         {
            openSELLHedge(volumnHedge, "Hedge đầu tiên");
         }
      }
      else if(ticketHedge > 0)
      {
         datetime timeStart = TimeCurrent() - 3600 * 24 * 3;
         if(!HistorySelect(timeStart, TimeCurrent())) 
         {
            return;
         }
         
         int totalDeals = HistoryDealsTotal();
         Print("totalDeals = " + IntegerToString(totalDeals));
         for(int i = totalDeals-1; i >= 0; i--)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket <= 0) 
               continue;
            
            ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            if(positionTicket != ticketHedge)
               continue;
            
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);   
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            ulong dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC); 
            if(dealMagic != Magic_Hedge || dealEntry != DEAL_ENTRY_OUT)
            {
               continue;
            }  
            if(profit > 0) 
            {
               ticketHedge = 0;
               break;
            }
            else 
            {
               double xVolumn = volume * 2;
               if(xVolumn > maxVolumnSellHedge)
               {
                 xVolumn = maxVolumnSellHedge;
               }
               openSELLHedge(xVolumn, "Hedge _ " + DoubleToString(xVolumn, 2));
               break;
            }
         }
      }
   }
   
   // tỉa lệnh
   //if(TimeCurrent() - lastCheckTiaLenh >= 60*60 && enableTiaLenh)
   //{
      tiaLenhThongMinh();
      lastCheckTiaLenh = TimeCurrent();
   //}
}

//+------------------------------------------------------------------+
//| Các hàm hỗ trợ                                                   |
//+------------------------------------------------------------------+

bool openBuy(double lot, double amountTakeProfit, string comment)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = price + amountTakeProfit;
   
   trade.SetExpertMagicNumber(EXPERT_MAGIC);
   if(trade.Buy(lot, _Symbol, price, 0, tp, comment))
   {
      Print("✅ Send buy success!");
      countOpenBuy++;
      return true;
   }
   else
   { 
      Print("❌ Gửi lệnh BUY lỗi: ", GetLastError());
      return false;
   }
}

bool openSELL(string comment)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = price - priceDCASell;
   
   trade.SetExpertMagicNumber(EXPERT_MAGIC);
   if(trade.Sell(volumnSell, _Symbol, price, 0, tp, comment))
   {
      Print("✅ Send Sell success!");
      return true;
   }
   else
   { 
      Print("❌ Gửi lệnh Sell lỗi: ", GetLastError());
      return false;
   }
}

bool openSELLHedge(double lot, string comment)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = price - priceSLTP;
   double sl = price + priceSLTP;
   
   trade.SetExpertMagicNumber(Magic_Hedge);
   if(trade.Sell(lot, _Symbol, price, sl, tp, comment))
   {
      Print("✅ SELL Hedge success!");
      ticketHedge = trade.ResultOrder();
      return true;
   }
   else
   { 
      Print("❌ SELL Hedge lỗi: ", GetLastError());
      return false;
   }
}

void getValuePosition(int totalPosition, double &priceDCA, double &volumn, double &takeprofit)
{
   if(totalPosition < level1) 
   {
      priceDCA = priceDCALv1;
      volumn = volumnLv1;
      takeprofit = takeProfitLv1;
   }
   else if(totalPosition < (level1 + level2))
   {
      priceDCA = priceDCALv2;
      volumn = volumnLv2;
      takeprofit = takeProfitLv2;
   } 
   else if(totalPosition < (level1 + level2 + level3))
   {
      priceDCA = priceDCALv3;
      volumn = volumnLv3;
      takeprofit = takeProfitLv3;
   }
   else if(totalPosition < (level1 + level2 + level3 + level4))
   {
      priceDCA = priceDCALv4;
      volumn = volumnLv4;
      takeprofit = takeProfitLv4;
   } 
   else 
   {
      priceDCA = priceDCALvLast;
      volumn = volumnLvLast;
      takeprofit = takeProfitLvLast;
   }   
}

void updateReport()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currenPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   int totalPosition = PositionsTotal();
   double maxProsition = MathSqrt((balance / 3) * 2);
   double leftPostion = maxProsition - double(totalPosition);
   double khoangGia = leftPostion * 3;
   double priceStopLoss = currenPrice - khoangGia;
   int sumProfit = (countOpenBuy - totalPosition) * 3;
   
   ObjectSetString(0, "stoploss", OBJPROP_TEXT, "Profit:" + IntegerToString(sumProfit) + " | " + DoubleToString(ddProfit, 1) + " |SL :" + DoubleToString(priceStopLoss, 1) + " | " + DoubleToString(khoangGia, 1));         
}

void paintlable()
{
   ObjectCreate(0, "stoploss", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "stoploss", OBJPROP_TEXT, "SL:0");
   ObjectSetInteger(0, "stoploss", OBJPROP_CORNER, CORNER_LEFT_LOWER); 
   ObjectSetInteger(0, "stoploss", OBJPROP_XDISTANCE, 200); 
   ObjectSetInteger(0, "stoploss", OBJPROP_YDISTANCE, 25); 
   ObjectSetInteger(0, "stoploss", OBJPROP_COLOR, clrYellow); 
   ObjectSetInteger(0, "stoploss", OBJPROP_BACK, true);
   ObjectSetInteger(0, "stoploss", OBJPROP_FONTSIZE, 16);
   ObjectSetString(0, "stoploss", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "stoploss", OBJPROP_BGCOLOR, clrWhite); 
}

string CheckTrend()
{
   
   // --- MA settings cho khung cao hơn
   int fastMAHigher = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   int slowMAHigher = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);

   double fastBufHigher[], slowBufHigher[];
   CopyBuffer(fastMAHigher, 0, 0, 3, fastBufHigher);
   CopyBuffer(slowMAHigher, 0, 0, 3, slowBufHigher);

   // --- MA settings cho khung hiện tại
   int fastMA = iMA(_Symbol, _Period, 14, 0, MODE_SMA, PRICE_CLOSE);
   int slowMA = iMA(_Symbol, _Period, 28, 0, MODE_SMA, PRICE_CLOSE);

   double fastBuf[], slowBuf[];
   CopyBuffer(fastMA, 0, 0, 3, fastBuf);
   CopyBuffer(slowMA, 0, 0, 3, slowBuf);

   // Kiểm tra xu hướng MA trên cả 2 khung thời gian
   bool trendUpHigher = fastBufHigher[0] > slowBufHigher[0] && fastBufHigher[1] > slowBufHigher[1];
   bool trendDownHigher = fastBufHigher[0] < slowBufHigher[0] && fastBufHigher[1] < slowBufHigher[1];
   
   bool trendUpCurrent = fastBuf[0] > slowBuf[0] && fastBuf[1] > slowBuf[1];
   bool trendDownCurrent = fastBuf[0] < slowBuf[0] && fastBuf[1] < slowBuf[1];

   // --- RSI với thiết lập làm mượt
   int rsiHandle = iRSI(_Symbol, _Period, 21, PRICE_CLOSE);
   double rsiBuf[];
   CopyBuffer(rsiHandle, 0, 0, 3, rsiBuf);
   double rsi = rsiBuf[0];
   double rsiPrev = rsiBuf[1];

   // --- MACD với thiết lập làm mượt
   int macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   double macdMain[], macdSignal[];
   CopyBuffer(macdHandle, 0, 0, 3, macdMain);
   CopyBuffer(macdHandle, 1, 0, 3, macdSignal);
   double macd = macdMain[0];
   double macdPrev = macdMain[1];

   // --- Price Action: xem xét nhiều nến hơn
   double lastHigh = MathMax(iHigh(_Symbol, _Period, 1), iHigh(_Symbol, _Period, 2));
   double lastLow  = MathMin(iLow(_Symbol, _Period, 1), iLow(_Symbol, _Period, 2));
   double price = iClose(_Symbol, _Period, 0);

   // --- Điều kiện xác nhận xu hướng mạnh mẽ hơn
   bool bullishCondition = trendUpHigher && trendUpCurrent && 
                          rsi > 55 && rsi > rsiPrev && 
                          macd > macdSignal[0] && macd > macdPrev &&
                          price > lastHigh;

   bool bearishCondition = trendDownHigher && trendDownCurrent && 
                          rsi < 45 && rsi < rsiPrev && 
                          macd < macdSignal[0] && macd < macdPrev &&
                          price < lastLow;

   // --- Logic xác định xu hướng
   if(bullishCondition)
   {
      return "UP_STRONG";
   }
   else if(bearishCondition)
   {
      return "DOWN_STRONG";
   }
   else
   {
      // Kiểm tra xu hướng yếu hơn
      bool weakBullish = trendUpCurrent && rsi > 50 && macd > 0 && price > lastHigh;
      bool weakBearish = trendDownCurrent && rsi < 50 && macd < 0 && price < lastLow;
      
      if(weakBullish) 
         return "UP_WEAK";
      else if(weakBearish) 
         return "DOWN_WEAK";
      else
         return "SIDEWAY";
   }
}


void drawArrow(string signal)
{
   double price = iClose(_Symbol, _Period, 0);
   datetime t = TimeCurrent();
   string arrowName = signal + "_ARROW_" + IntegerToString(t);
   string textName  = signal + "_TEXT_"  + IntegerToString(t);

   // Nếu là tín hiệu BUY
   if(signal == "UP_WEAK" || signal == "UP_STRONG")
   {
      // Mũi tên BUY to rõ
      ObjectCreate(0, arrowName, OBJ_ARROW_BUY, 0, t, price - 30 * _Point);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);

      // Thêm chữ BUY phía trên mũi tên
      ObjectCreate(0, textName, OBJ_TEXT, 0, t, price - 60 * _Point);
      ObjectSetString(0, textName, OBJPROP_TEXT, signal);
      ObjectSetInteger(0, textName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   }

   // Nếu là tín hiệu SELL
   if(signal == "DOWN_WEAK" || signal == "DOWN_STRONG")
   {
      // Mũi tên SELL to rõ
      ObjectCreate(0, arrowName, OBJ_ARROW_SELL, 0, t, price + 30 * _Point);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);

      // Thêm chữ SELL phía trên mũi tên
      ObjectCreate(0, textName, OBJ_TEXT, 0, t, price + 60 * _Point);
      ObjectSetString(0, textName, OBJPROP_TEXT, signal);
      ObjectSetInteger(0, textName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_TOP);
   }
}

ulong findWorstPosition()
{
   ulong worstTicket = 0;
   double worstScore = -999999;  
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         
         // Chỉ xét lệnh của bot (không phải lệnh manual)
         if(magic == EXPERT_MAGIC || magic == Magic_Hedge)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                 
            double score = profit;  
            
            if(score < worstScore)
            {
               worstScore = score;
               worstTicket = ticket;
            }
         }
      }
   }
   
   return worstTicket;
}


//+------------------------------------------------------------------+
//| Tỉa lệnh thông minh dựa trên nhiều yếu tố                       |
//+------------------------------------------------------------------+
void tiaLenhThongMinh()
{
   if(PositionsTotal() < soLenhToiThieuDeTia) return;
   
   // 1. Tỉa theo xu hướng thị trường
   if(currentTrend == "DOWN_STRONG" || currentTrend == "DOWN_WEAK") tiaLenhTheoTrend(POSITION_TYPE_BUY);
   if(currentTrend == "UP_STRONG" || currentTrend == "UP_WEAK") tiaLenhTheoTrend(POSITION_TYPE_SELL);
   
   // 2. Tỉa theo mức drawdown
   if(ddProfit < -AccountInfoDouble(ACCOUNT_BALANCE) * maxDrawdow) tiaLenhTheoRisk();
   
}

//+------------------------------------------------------------------+
//| Tỉa lệnh theo xu hướng thị trường                               |
//+------------------------------------------------------------------+
void tiaLenhTheoTrend(ENUM_POSITION_TYPE trendToClose)
{
   int closed = 0;
   for(int i = PositionsTotal()-1; i >= 0 && closed < 2; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_TYPE) == trendToClose)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit > 0) // Chỉ đóng lệnh có lời
         {
            trade.PositionClose(ticket);
            closed++;
            Print("✅ Đóng lệnh ", ticket , EnumToString(trendToClose), " theo trend | Lợi nhuận: ", profit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Tỉa lệnh theo risk management                                   |
//+------------------------------------------------------------------+
void tiaLenhTheoRisk()
{
   double totalRisk = 0;
   int closed = 0;
   
   // Sắp xếp lệnh theo mức độ rủi ro
   for(int i = 0; i < 2; i++) // Đóng 2 lệnh xấu nhất
   {
      ulong worstTicket = findWorstPositionAdvanced();
      if(worstTicket != 0)
      {
         PositionSelectByTicket(worstTicket);
         double profit = PositionGetDouble(POSITION_PROFIT);
         trade.PositionClose(worstTicket);
         Print("Đóng lệnh: " , worstTicket);
         totalRisk += profit;
         closed++;
      }
   }
   
   if(closed > 0) Print("⚠️ Đóng ", closed, " lệnh rủi ro | Tổng giảm lỗ: " , totalRisk);
}

//+------------------------------------------------------------------+
//| Tìm lệnh xấu nhất phiên bản nâng cao                            |
//+------------------------------------------------------------------+
ulong findWorstPositionAdvanced()
{
   ulong worstTicket = 0;
   double worstScore = -999999;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(magic == EXPERT_MAGIC || magic == Magic_Hedge)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double currentPrice = (type == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            // 📊 CÔNG THỨC ĐIỂM THÔNG MINH:
            double distance = MathAbs(currentPrice - entryPrice) / _Point;
            double timeOpen = double(TimeCurrent() - PositionGetInteger(POSITION_TIME));
            
            // Điểm số kết hợp nhiều yếu tố
            double score = profit * 0.5                    // Lợi nhuận (quan trọng nhất)
                         + (profit / volume) * 0.3        // Lợi nhuận trên mỗi lot
                         + distance * 0.1                 // Khoảng cách từ entry
                         + timeOpen * 0.1;                // Thời gian mở lệnh
            
            // Phạt nặng lệnh ngược trend
            if((type == POSITION_TYPE_BUY && (currentTrend == "DOWN_STRONG" || currentTrend == "DOWN_WEAK")) ||
               (type == POSITION_TYPE_SELL && (currentTrend == "UP_STRONG" || currentTrend == "UP_WEAK")))
            {
               score *= 2; // Ưu tiên đóng gấp đôi
            }
            
            if(score < worstScore)
            {
               worstScore = score;
               worstTicket = ticket;
            }
         }
      }
   }
   
   return worstTicket;
}
