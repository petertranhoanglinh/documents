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
bool  openSellDCA  = false; // Tắt/Mở chức năng
input double volumnSell  = 0.01; // Số lot mở lệnh
input double priceDCASell = 3; // Khoảng giá mua thêm 
input double takeProfitSell = 3; // Chốt lời với khoảng giá
double xVolumnSell = 1;
datetime checkTimeTiaLenh;
double xPriceDca = 1;

datetime lastTrendOpenTime;



input group "__2 Thêm BOT SELL Hỗ Trợ Khi Âm TK"
bool  openHedge  = false; // Tắt/Mở chức năng
input int conditonNumBuyOpen = 10; // Bắt đầu khi có số lệnh BUY đang mở
input double  volumnHedge  = 0.01; // Số lot mở lệnh
input double  priceSLTP  = 3; // Giá đặt Stoploss và Takeprofit
input double  maxVolumnSellHedge = 2; // Max Volumn Khi mở lệnh sell hedge

input group "[TỈA LỆNH] CẤU HÌNH TỈA LỆNH";
bool  enableTiaLenh = true; // Bật/tắt chức năng tỉa lệnh
input int  soLenhToiThieuDeTia = 30; // Số lệnh tối thiểu để tỉa
input double maxDrawdow = 30; // drawdow tài khoản cần tỉa viết 1 -> 100


input group "Một số cài đặt phòng thủ khác";
input double rateDropDownDisableBuy = 20; // phần trăm giới hạn lỗ so với tài khoản để tắt BUY

bool disableBuy = false;

int Magic_Hedge = 111;
int Magic_Trend = 1111;
ulong ticketHedge = 0; 
int countOpenBuy = 0;
double ddProfit = 0;

int maHandle;
double maBuffer[];
string currentTrend = "SIDEWAY"; 

//--- handle chỉ báo
int halfTrendHandle;
input group "__4 Thông số chỉ báo"
input int    InpAmplitude   = 5;     // Amplitude
input uchar  InpCodeUpArrow = 233;   // Arrow code for 'UpArrow' (Wingdings)
input uchar  InpCodeDnArrow = 234;   // Arrow code for 'DnArrow' (Wingdings)
input int    InpShift       = 10;    // Vertical shift of arrows
int signal;
double lastProfitInDowntrend = 0;
int currentSign = 0;


 int totalPositonBUY = 0;
 int totalPositonSELL = 0;
 int totalPositonHedge = 0;
 int totalProfitBuy = 0;
 int totalProfitSell = 0;
double downtrendStartPrice = 0; // Giá khi bắt đầu downtrend
datetime downtrendStartTime = 0; // Thời gian bắt đầu downtrend

double deposit = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   paintlable();
   halfTrendHandle = iCustom(_Symbol, _Period, 
                             "HalfTrend",  
                             InpAmplitude,
                             InpCodeUpArrow,
                             InpCodeDnArrow,
                             InpShift);
   if(halfTrendHandle == INVALID_HANDLE)
   {
      Print("❌ Không load được Half Trend New. Lỗi: ", GetLastError());
      return(INIT_FAILED);
   }
   deposit = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(halfTrendHandle != INVALID_HANDLE)
   {
      IndicatorRelease(halfTrendHandle);
   }
   // Xóa tất cả các đối tượng vẽ
   ObjectsDeleteAll(0, -1, -1);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   updateReport(); 
   datetime currentTime = iTime(_Symbol, _Period, 0);
   datetime signalTime;
   double signalPrice;
   signal = GetHalfTrendSignal(signalTime, signalPrice);
   if(signal != 0)
   {
      string trendText = (signal == 1) ? "UPTREND" : "DOWNTREND";
      Print("Tín hiệu ", trendText, " tại: ", TimeToString(signalTime), 
            ", Giá: ", DoubleToString(signalPrice, _Digits));
      //--- Kiểm tra đây có phải tín hiệu mới không
      static datetime lastSignalTime = 0;
      CloseAllMagicTrendOrders();
      if(signalTime > lastSignalTime)
      {
         lastSignalTime = signalTime;
         Print("TÍN HIỆU MỚI: ", trendText, " - Xử lý giao dịch...");
         //--- Thêm logic giao dịch của bạn ở đây
         if(signal == 1) 
         {
            double lowPrice = iLow(_Symbol, _Period, 1);
            xPriceDca = 1;
            DrawText("UP_" + IntegerToString(currentTime), "UPTREND", currentTime, lowPrice, clrDeepSkyBlue);
            disableBuy = false;  
            downtrendStartTime = 0;
         }
         else if(signal == -1) 
         {
            downtrendStartPrice = iHigh(_Symbol, _Period, 1);
            downtrendStartTime = TimeCurrent();
            double highPrice = iHigh(_Symbol, _Period, 1);
            DrawText("DOWN_" + IntegerToString(currentTime), "DOWNTREND", currentTime, highPrice, clrOrangeRed);
         }
      }
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);   // số dư gốc
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);    // vốn thực tế hiện tại
   double profit  = equity - balance; 
   Print("DrawDown là: " , MathAbs(profit) / equity);     
   double drawDown = MathAbs(profit) / equity;
   if(rateDropDownDisableBuy / 100 > drawDown){
     disableBuy = true;
   }
   if(downtrendStartTime > 0 && downtrendStartPrice > 0  ){
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double priceDrop = (downtrendStartPrice - currentPrice) / _Point;
      if((downtrendStartPrice - currentPrice) > 50 && drawDown > 0.2){
        CloseLossingBuyOrders(60);
      }
   }
   if (drawDown > 0.05 && signal == -1){
     xPriceDca = 1.2; 
     openSellTrend();
   }
   if (drawDown < 0.1){
      disableBuy = false;
      openSellDCA = false;
      openHedge = false;
      xPriceDca = 1;
   }  
   double minPriceBuy = DBL_MAX;
   double hightPriceBuy = 0;
   ddProfit = 0;
   double hightPriceSELL = 0; 
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
      openBuy(volumnLv1 * xPriceDca, takeProfitLv1, "Lệnh đầu tiền");
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
         openBuy(volumn * xPriceDca, takeprofit, "BUY|" + IntegerToString(totalPositonBUY) + "|");
      }
   } 
   // Handle SELL DCA 
   if(openSellDCA == true)
   {
      double spacePriceSELL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - hightPriceSELL;
      if(totalPositonSELL == 0)
      {
         openSELL("Lệnh đầu tiền" , volumnSell * xVolumnSell);
      }
      else if(spacePriceSELL > priceDCASell)
      {
         openSELL("DCA SELL|" + IntegerToString(totalPositonSELL) + "|" , volumnSell);
      }
   }
   // Handle SELL HEDGE
   if(openHedge == true && totalPositonHedge == 0)
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
}
//+------------------------------------------------------------------+
//| Các hàm hỗ trợ                                                   |
//+------------------------------------------------------------------+
bool openBuy(double lot, double amountTakeProfit, string comment)
{
   if(disableBuy)
   {
    return false;
   }
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

bool openSELL(string comment , double volumn)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = price - takeProfitSell;
   if(comment == "SELL_TREND"){
     trade.SetExpertMagicNumber(Magic_Trend);
   }else{
    trade.SetExpertMagicNumber(EXPERT_MAGIC);
   }
   double slValue = 0;
   
   if(comment == "SELL_TREND"){
      slValue =  price + takeProfitSell;
   }

   if(trade.Sell(volumn, _Symbol, price, slValue, tp, comment))

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
//+------------------------------------------------------------------+
//| Hàm vẽ chữ trên chart                                            |
//+------------------------------------------------------------------+
void DrawText(string name, string text, datetime t, double price, color clr)
{
   // Xóa đối tượng cũ nếu tồn tại
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   // Tạo đối tượng text mới
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
   {
      Print("Lỗi tạo text object: ", GetLastError());
      return;
   }

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}
//+------------------------------------------------------------------+
//| Lấy tín hiệu Half Trend với thời gian chính xác                  |
//+------------------------------------------------------------------+
int GetHalfTrendSignal(datetime &signalTime, double &signalPrice)
{
   signalTime = 0;
   signalPrice = 0.0;
   
   if(halfTrendHandle == INVALID_HANDLE) 
      return 0;

   double upArrow[], downArrow[];
   datetime time[];
   ArraySetAsSeries(upArrow, true);
   ArraySetAsSeries(downArrow, true);
   ArraySetAsSeries(time, true);

   //--- Lấy dữ liệu mũi tên Buy (buffer 2), Sell (buffer 3) và thời gian
   if(CopyBuffer(halfTrendHandle, 2, 0, 3, upArrow) < 0 ||
      CopyBuffer(halfTrendHandle, 3, 0, 3, downArrow) < 0 ||
      CopyTime(Symbol(), Period(), 0, 3, time) < 0)
   {
      Print("Lỗi CopyBuffer/CopyTime: ", GetLastError());
      return 0;
   }

   //--- Kiểm tra tín hiệu ở nến trước (index 1)
   if(upArrow[1] != 0.0 && upArrow[1] != EMPTY_VALUE)
   {
      signalTime = time[1];
      signalPrice = upArrow[1];
      return 1; // UPTREND
   }
   else if(downArrow[1] != 0.0 && downArrow[1] != EMPTY_VALUE)
   {
      signalTime = time[1];
      signalPrice = downArrow[1];
      return -1; // DOWNTREND
   }

   return 0; // KHÔNG CÓ TÍN HIỆU
}

void CloseLossingBuyOrders(double rateClose)
{        
    // Chuyển đổi tỷ lệ từ phần trăm sang thập phân
    rateClose = rateClose / 100;
    
    // Mảng lưu trữ thông tin các lệnh BUY đang lỗ
    MqlRates rates[];
    double openPrices[];
    long positionTimes[];
    ulong tickets[];
    int lossingCount = 0;
    
    // Lấy dữ liệu giá để xác định lệnh xa nhất
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, PositionsTotal(), rates);
    if(copied <= 0)
    {
        Print("Không thể lấy dữ liệu giá. Lỗi: ", GetLastError());
        return;
    }
    
    // Đếm và thu thập thông tin lệnh BUY đang lỗ
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == EXPERT_MAGIC &&
           PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < 0)
            {
                // Mở rộng mảng để lưu thông tin
                ArrayResize(openPrices, lossingCount+1);
                ArrayResize(positionTimes, lossingCount+1);
                ArrayResize(tickets, lossingCount+1);
                
                // Lưu thông tin lệnh
                openPrices[lossingCount] = PositionGetDouble(POSITION_PRICE_OPEN);
                positionTimes[lossingCount] = PositionGetInteger(POSITION_TIME);
                tickets[lossingCount] = ticket;
                
                lossingCount++;
            }
        }
    }
    
    if(lossingCount <= 0) 
    {
        Print("Không có lệnh BUY nào đang lỗ");
        return;
    }
    
    // Tính số lệnh cần đóng (làm tròn lên)
    int ordersToClose = (int)MathCeil(lossingCount * rateClose);
    if(ordersToClose <= 0) 
    {
        Print("Số lệnh cần đóng là 0");
        return;
    }
    
    Print("Tổng số lệnh BUY đang lỗ: ", lossingCount, " - Số lệnh cần đóng: ", ordersToClose);
    
    // Sắp xếp lệnh theo khoảng cách so với giá hiện tại (xa nhất trước)
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distances[];
    ArrayResize(distances, lossingCount);
    
    for(int i = 0; i < lossingCount; i++)
    {
        distances[i] = MathAbs(currentPrice - openPrices[i]);
    }
    
    // Sắp xếp giảm dần theo khoảng cách (xa nhất đầu tiên)
    for(int i = 0; i < lossingCount-1; i++)
    {
        for(int j = i+1; j < lossingCount; j++)
        {
            if(distances[j] > distances[i])
            {
                // Hoán đổi khoảng cách
                double tempDist = distances[i];
                distances[i] = distances[j];
                distances[j] = tempDist;
                
                // Hoán đổi ticket
                ulong tempTicket = tickets[i];
                tickets[i] = tickets[j];
                tickets[j] = tempTicket;
                
                // Hoán đổi giá mở
                double tempPrice = openPrices[i];
                openPrices[i] = openPrices[j];
                openPrices[j] = tempPrice;
            }
        }
    }
    
    // Đóng các lệnh theo thứ tự đã sắp xếp (xa nhất trước)
    int closedCount = 0;
    for(int i = 0; i < lossingCount && closedCount < ordersToClose; i++)
    {
        Print("Đóng lệnh BUY #", tickets[i], " - Giá mở: ", DoubleToString(openPrices[i], Digits()), 
              " - Khoảng cách: ", DoubleToString(distances[i], Digits()), " pips (", closedCount + 1, "/", ordersToClose, ")");
        
        if(!trade.PositionClose(tickets[i]))
            Print("Lỗi đóng lệnh #", tickets[i], ": ", GetLastError());
        else
            closedCount++; // Tăng biến đếm chỉ khi đóng thành công
    }
    
    Print("Đã đóng thành công ", closedCount, "/", ordersToClose, " lệnh (ưu tiên lệnh xa nhất trước)");
}
//+------------------------------------------------------------------+
//| HÀM ĐÓNG TẤT CẢ LỆNH THEO MAGIC NUMBER                          |
//+------------------------------------------------------------------+
void CloseAllMagicTrendOrders()
{
    int closedCount = 0;
    
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) == Magic_Trend)
        {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            if(profit < 3){
               return;
            }
            if(trade.PositionClose(ticket))
            {
                closedCount++;
                Print("✅ Đã đóng lệnh #", ticket, " thành công");
            }
            else
            {
                Print("❌ Lỗi đóng lệnh #", ticket, ": ", trade.ResultRetcodeDescription());
            }
        }
    }
    if(closedCount > 0)
    {
        Print("Đã đóng ", closedCount, " lệnh với Magic Number: ", Magic_Trend);
    }
}

bool CanOpenSellTrend()
{
    double totalBuyVolume = 0.0;
    double totalSellVolume = 0.0;
    double totalBuyProfit = 0.0;
    bool hasLossingBuy = false;
    
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == EXPERT_MAGIC)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY)
            {
                totalBuyVolume += volume;
                totalBuyProfit += profit;
                if(profit < 0)
                {
                    hasLossingBuy = true;
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                totalSellVolume += volume;
            }
        }
    }
    totalBuyVolume = totalBuyVolume +  (MathAbs(totalBuyProfit) / 3.0 * 0.01);
    if(totalBuyVolume > totalSellVolume && 
       hasLossingBuy && 
       totalBuyProfit < 0 && 
       totalBuyVolume >= 0.1)
    {
        return true;
    }
    return false;
}

void openSellTrend(){
   if(CanOpenSellTrend()){
          int sellCount = 0;
          for(int i = 0; i < PositionsTotal(); i++)
          {
              ulong ticket = PositionGetTicket(i);
              if(PositionSelectByTicket(ticket))
              {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
                     PositionGetInteger(POSITION_MAGIC) == Magic_Trend &&
                     PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  {
                      sellCount++;
                  }
              }
          }
          
          int currentCycle = sellCount / 50;  
          int positionInCycle = sellCount % 50; 
          double lotSize;
          if(positionInCycle == 0)
          {
              lotSize = 0.01;  
          }
          else
          {
              lotSize = positionInCycle * 0.01;
          }
          if(positionInCycle < 50 && totalPositonSELL < 50)
          {
              openSELL("SELL_TREND", 0.01);
          } 
   }
}
//+------------------------------------------------------------------+
