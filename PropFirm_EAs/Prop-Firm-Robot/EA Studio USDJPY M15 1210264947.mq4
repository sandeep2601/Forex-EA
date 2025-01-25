/**
 * EA Studio Expert Advisor
 *
 * Exported from Expert Advisor Studio
 * MQL base code updated on 2024-08-22
 * Website https://studio.eatradingacademy.com/
 *
 * Copyright 2024, Forex Software Ltd.
 *
 * Risk Disclosure
 *
 * Futures and forex trading contains substantial risk and is not for every investor.
 * An investor could potentially lose all or more than the initial investment.
 * Risk capital is money that can be lost without jeopardizing ones’ financial security or life style.
 * Only risk capital should be used for trading and only those with sufficient risk capital should consider trading.
 */

#property copyright "Forex Software Ltd."
#property version   "6.2"
#property strict

static input string _Properties_ = "------"; // --- Expert Properties ---
static input int    Magic_Number = 1210264947; // Magic number
static input double Entry_Amount =     0.65; // Entry lots
       input int    Stop_Loss    =       42; // Stop Loss   (pips)
       input int    Take_Profit  =       90; // Take Profit (pips)

static input string ___0______   = "------"; // --- Directional Indicators ---
       input int    Ind0Param0   =       23; // Period

static input string ___1______   = "------"; // --- Bulls Power ---
       input int    Ind1Param0   =       29; // Period
       input double Ind1Param1   =   0.0000; // Level

static input string ___2______   = "------"; // --- Candle Color ---
       input int    Ind2Param0   =       28; // Min body height [pips]
       input int    Ind2Param1   =        3; // Consecutive candles

static input string Entry_prot__ = "------"; // --- Entry Protections ---
static input int    Max_Spread   =        0; // Max spread (points)
static input int    Max_OpenPos  =        0; // Max open positions (all experts)
static input double Max_OpenLots =     0.00; // Max open lots (all experts)

static input string Daily_prot__ = "------"; // --- Daily Protections ---
static input int    MaxDailyLoss =        0; // Maximum daily loss (currency)
static input double Max_Daily_DD =     0.00; // Maximum daily drawdown %
static input int    Daily_Reset  =        0; // Daily reset hour (terminal time)

static input string Account_prot = "------"; // --- Account Protections ---
static input int    Min_Equity   =        0; // Minimum equity (currency)
static input double MaxEquity_DD =     0.00; // Maximum equity drawdown %
static input int    Max_Equity   =        0; // Maximum equity (currency)

static input string _NewsFilter_ = "------"; // --- News Filter ---
enum NewsFilterPriority
  {
   NewsFilter_Disabled,     // News filter disabled
   NewsFilter_HighOnly,     // High news filter
   NewsFilter_HighAndMedium // Medium and High news filter
  };
static input NewsFilterPriority News_Priority = NewsFilter_Disabled;       // News priority
static input string News_Currencies   = "USD,JPY,EUR"; // News currencies
static input int    News_BeforeMedium =  2; // Before Medium news (minutes)
static input int    News_AfterMedium  =  2; // After Medium news (minutes)
static input int    News_BeforeHigh   =  2; // Before High news (minutes)
static input int    News_AfterHigh    =  5; // After High news (minutes)
static input int    News_ViewCount    = 10; // News records to show

static input string __Stats_____ = "------"; // --- Stats ---
static input bool   Pos_Stat     =     true; // Position stats
static input bool   Robot_Stats  =     true; // Robot stats

#define TRADE_RETRY_COUNT   4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT            -1

string robotTagline  = "An Expert Advisor from Expert Advisor Studio";

// Session time is set in seconds from 00:00
int  sessionSundayOpen          =     0; // 00:00
int  sessionSundayClose         = 86400; // 24:00
int  sessionMondayThursdayOpen  =     0; // 00:00
int  sessionMondayThursdayClose = 86400; // 24:00
int  sessionFridayOpen          =     0; // 00:00
int  sessionFridayClose         = 86400; // 24:00
bool sessionIgnoreSunday        = false;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;

const double sigma = 0.000001;

int    posType       = OP_FLAT;
int    posTicket     = 0;
double posLots       = 0;
double posStopLoss   = 0;
double posTakeProfit = 0;
double posProfit     = 0;
double posPriceOpen  = 0;
double posPriceCurr  = 0;

datetime lastStatsUpdate = 0;
datetime barTime;
double   pip;
double   stopLevel;
bool     isTrailingStop=false;
bool     setProtectionSeparately = false;

int    maxRectangles = 0;
int    maxLabels     = 0;
int    posStatCount  = 0;
double posStatLots   = 0;

string accountProtectionMessage = "";
string entryProtectionMessage   = "";

struct NewsRecord
  {
   datetime time;
   string   priority;
   string   currency;
   string   title;
  };

NewsRecord newsRecords[];
string   newsCurrencies[];
datetime lastNewsUpdate = 0;
string   loadNewsError  = "";
bool     isNewsFeedOk   = true;

string   accMaxEquityGlobalVarName       = "accMaxEquity123456789";
string   accMaxDailyBalanceGlobalVarName = "accMaxDailyBalance123456789";
string   accMaxDailyEquityGlobalVarName  = "accMaxDailyEquity123456789";
string   accEntrySuspendGlobalVarName    = "accEntrySuspend123456789";
double   equityDrawdownPercent           = 0;
datetime dailyDrawdownLastReset          = 0;
double   dailyLoss                       = 0;
double   dailyDrawdown                   = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   Comment("");
   DeleteObjects();

   barTime         = Time[0];
   stopLevel       = MarketInfo(_Symbol, MODE_STOPLEVEL);
   pip             = GetPipValue();
   isTrailingStop  = isTrailingStop && Stop_Loss > 0;
   lastStatsUpdate = 0;

   accountProtectionMessage = "";
   entryProtectionMessage   = "";

   InitGlobalVariables();
   UpdatePosition();

   ParseNewsCurrenciesText();
   lastNewsUpdate = TimeCurrent();
   if(!MQLInfoInteger(MQL_TESTER))
      LoadNews();

   OnTick();
   ChartRedraw(0);

   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjects();

   if(accountProtectionMessage != "")
      Comment(accountProtectionMessage);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      UpdatePosition();
      UpdateAccountProtection();
      CheckAccountProtection();

      const datetime time = TimeCurrent();
      if(time > lastStatsUpdate + 3)
        {
         lastStatsUpdate = time;
         if(Max_OpenPos || Max_OpenLots)
            SetPosStats();

         UpdateStats();
        }

      if(time > lastNewsUpdate + 6*60*60 || !isNewsFeedOk)
        {
         lastNewsUpdate = time;
         LoadNews();
        }
     }

   const datetime time = Time(0);
   if(time > barTime)
     {
      barTime = time;
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar(void)
  {
   UpdatePosition();

   if(posType != OP_FLAT && IsForceSessionClose())
     {
      ClosePosition();
      return;
     }

   if(IsOutOfSession())
      return;

   if(posType != OP_FLAT)
     {
      ManageClose();
      UpdatePosition();
     }

   if(posType != OP_FLAT && isTrailingStop)
     {
      const double trailingStop = GetTrailingStopPrice();
      ManageTrailingStop(trailingStop);
      UpdatePosition();
     }

   int entrySignal = GetEntrySignal();

   if(posType == OP_FLAT && entrySignal != OP_FLAT)
     {
      OpenPosition(entrySignal);
      UpdatePosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition(void)
  {
   posType       = OP_FLAT;
   posTicket     = 0;
   posLots       = 0;
   posProfit     = 0;
   posStopLoss   = 0;
   posTakeProfit = 0;
   posPriceOpen  = 0;
   posPriceCurr  = 0;

   for(int pos = OrdersTotal() - 1; pos >= 0; pos -= 1)
     {
      if(OrderSelect(pos, SELECT_BY_POS) &&
         OrderSymbol()      == _Symbol   &&
         OrderMagicNumber() == Magic_Number)
        {
         posType       = OrderType();
         posTicket     = OrderTicket();
         posLots       = OrderLots();
         posProfit     = OrderProfit();
         posStopLoss   = OrderStopLoss();
         posTakeProfit = OrderTakeProfit();
         posPriceOpen  = NormalizeDouble(OrderOpenPrice(),  _Digits);
         posPriceCurr  = NormalizeDouble(OrderClosePrice(), _Digits);
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetEntrySignal(void)
  {
   // Directional Indicators (23)
   double ind0val1  = iADX(NULL, 0, Ind0Param0, PRICE_CLOSE, 1, 1);
   double ind0val2  = iADX(NULL ,0 ,Ind0Param0, PRICE_CLOSE, 2, 1);
   double ind0val3  = iADX(NULL, 0, Ind0Param0, PRICE_CLOSE, 1, 2);
   double ind0val4  = iADX(NULL ,0 ,Ind0Param0, PRICE_CLOSE, 2, 2);
   bool   ind0long  = ind0val1 > ind0val2 + sigma && ind0val3 < ind0val4 - sigma;
   bool   ind0short = ind0val1 < ind0val2 - sigma && ind0val3 > ind0val4 + sigma;

   // Bulls Power (29), Level: 0.0000
   double ind1val1  = iBullsPower(NULL, 0, Ind1Param0, PRICE_CLOSE, 1);
   bool   ind1long  = ind1val1 > Ind1Param1 + sigma;
   bool   ind1short = ind1val1 < -Ind1Param1 - sigma;

   bool canOpenLong  = ind0long && ind1long;
   bool canOpenShort = ind0short && ind1short;

   return canOpenLong  && !canOpenShort ? OP_BUY
        : canOpenShort && !canOpenLong  ? OP_SELL
        : OP_FLAT;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose(void)
  {
   // Candle Color (28, 3)
   bool ind2long  = false;
   bool ind2short = false;
   {
      int consecutiveBullish = 0;
      int consecutiveBearish = 0;
      double pipVal = pip * Ind2Param0;

      for (int b = Ind2Param1 + 2; b > 0; b--)
        {
         consecutiveBullish = Close(b) - Open(b) >= pipVal ? consecutiveBullish + 1 : 0;
         consecutiveBearish = Open(b) - Close(b) >= pipVal ? consecutiveBearish + 1 : 0;
        }

      ind2long  = consecutiveBearish >= Ind2Param1;
      ind2short = consecutiveBullish >= Ind2Param1;
   }

   if((posType == OP_BUY  && ind2long) ||
        (posType == OP_SELL && ind2short) )
      ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(const int command)
  {
   entryProtectionMessage = "";
   const int spread = (int)((Ask() - Bid()) / _Point);
   if(Max_OpenPos > sigma && posStatCount >= Max_OpenPos)
      entryProtectionMessage += StringFormat("Protection: Max open positions: %d, current: %d\n",
                                             Max_OpenPos, posStatCount);
   if(Max_OpenLots > sigma && posStatLots > Max_OpenLots - sigma)
      entryProtectionMessage += StringFormat("Protection: Max open lots: %.2f, current: %.2f\n",
                                             Max_OpenLots, posStatLots);
   if(Max_Spread > sigma && spread > Max_Spread)
      entryProtectionMessage += StringFormat("Protection: Max spread: %d, current: %d\n",
                                             Max_Spread, spread);
   if(MaxDailyLoss > sigma && dailyLoss >= MaxDailyLoss)
      entryProtectionMessage += StringFormat("Protection: Max daily loss: %d, current: %.2f\n",
                                             MaxDailyLoss, dailyLoss);
   if(Max_Daily_DD > sigma && dailyDrawdown >= Max_Daily_DD)
      entryProtectionMessage += StringFormat("Protection: Max daily drawdown: %.2f%%, current: %.2f%%\n",
                                             Max_Daily_DD, dailyDrawdown);
   if(GlobalVariableGet(accEntrySuspendGlobalVarName) > sigma)
      entryProtectionMessage += StringFormat("New entries are suspended until the Daily reset hour: %d",
                                             Daily_Reset);

   const int newsIndex = NewsFilterActive();
   if(newsIndex > -1)
     {
      const NewsRecord newsRecord = newsRecords[newsIndex];
      const datetime timeShift = (datetime) MathRound((TimeLocal() - TimeGMT()) / 3600.0) * 3600;
      const string   priority  = newsRecord.priority == "high" ? "[high]" : "[med]";
      entryProtectionMessage  += StringFormat("News filter: %s %s %s %s\n",
                                              priority,
                                              TimeToString(newsRecord.time + timeShift,
                                                           TIME_DATE | TIME_MINUTES),
                                              newsRecord.currency,
                                              newsRecord.title);
     }

   if(entryProtectionMessage != "")
     {
      entryProtectionMessage = TimeToString(TimeCurrent()) + " " +
                               "An entry order was canceled:\n" +
                               entryProtectionMessage;
      return;
     }

   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      int    ticket     = 0;
      int    lastError  = 0;
      bool   modified   = false;
      string comment    = IntegerToString(Magic_Number);
      color  arrowColor = command == OP_BUY ? clrGreen : clrRed;

      if(IsTradeContextFree())
        {
         const double price      = command == OP_BUY ? Ask() : Bid();
         const double stopLoss   = GetStopLossPrice(command);
         const double takeProfit = GetTakeProfitPrice(command);

         if(setProtectionSeparately)
           {
            // Send an entry order without SL and TP
            ticket = OrderSend(_Symbol, command, Entry_Amount, price, 10, 0, 0, comment, Magic_Number, 0, arrowColor);

            // If the order is successful, modify the position with the corresponding SL and TP
            if(ticket > 0 && (Stop_Loss > 0 || Take_Profit > 0))
               modified = OrderModify(ticket, 0, stopLoss, takeProfit, 0, clrBlue);
           }
         else
           {
            // Send an entry order with SL and TP
            ticket    = OrderSend(_Symbol, command, Entry_Amount, price, 10, stopLoss, takeProfit, comment, Magic_Number, 0, arrowColor);
            lastError = GetLastError();

            // If order fails, check if it is because inability to set SL or TP
            if(ticket <= 0 && lastError == 130)
              {
               // Send an entry order without SL and TP
               ticket = OrderSend(_Symbol, command, Entry_Amount, price, 10, 0, 0, comment, Magic_Number, 0, arrowColor);

               // Try setting SL and TP
               if(ticket > 0 && (Stop_Loss > 0 || Take_Profit > 0))
                  modified = OrderModify(ticket, 0, stopLoss, takeProfit, 0, clrBlue);

               // Mark the expert to set SL and TP with a separate order
               if(ticket > 0 && modified)
                 {
                  setProtectionSeparately = true;
                  Print("Detected ECN type position protection.");
                 }
              }
           }
        }

      if(ticket > 0) break;

      lastError = GetLastError();
      if(lastError != 135 && lastError != 136 && lastError != 137 && lastError != 138)
         break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Open Position retry: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition(void)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      bool closed;
      int lastError = 0;

      if(IsTradeContextFree())
        {
         const double price = posType == OP_BUY ? Bid() : Ask();
         closed    = OrderClose(posTicket, posLots, price, 10, clrYellow);
         lastError = GetLastError();
        }

      if(closed) break;
      if(lastError == 4108) break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Close Position retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(void)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      bool modified;
      int lastError = 0;

      if(IsTradeContextFree())
        {
         modified  = OrderModify(posTicket, 0, posStopLoss, posTakeProfit, 0, clrBlue);
         lastError = GetLastError();
        }

      if(modified)
         break;

      if(lastError == 4108) break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Modify Position retry: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(const int command)
  {
   if(Stop_Loss == 0)
      return 0;

   const double delta    = MathMax(pip * Stop_Loss, _Point * stopLevel);
   const double stopLoss = command == OP_BUY ? Bid() - delta : Ask() + delta;

   return NormalizeDouble(stopLoss, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(const int command)
  {
   if(Take_Profit == 0)
      return 0;

   const double delta      = MathMax(pip * Take_Profit, _Point * stopLevel);
   const double takeProfit = command == OP_BUY ? Bid() + delta : Ask() - delta;

   return NormalizeDouble(takeProfit, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStopPrice(void)
  {
   const double bid = Bid();
   const double ask = Ask();
   const double spread = ask - bid;
   const double stopLevelPoints = _Point * stopLevel;
   const double stopLossPoints  = pip * Stop_Loss;

   if(posType == OP_BUY)
     {
      const double newStopLoss = High(1) - stopLossPoints;
      if(posStopLoss <= newStopLoss - pip)
         return newStopLoss < bid
                  ? newStopLoss >= bid - stopLevelPoints
                     ? bid - stopLevelPoints
                     : newStopLoss
                  : bid;
     }

   if(posType == OP_SELL)
     {
      const double newStopLoss = Low(1) + spread + stopLossPoints;
      if(posStopLoss >= newStopLoss + pip)
         return newStopLoss > ask
                  ? newStopLoss <= ask + stopLevelPoints
                     ? ask + stopLevelPoints
                     : newStopLoss
                  : ask;
     }

   return posStopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(const double trailingStop)
  {
   if((posType == OP_BUY  && MathAbs(trailingStop - Bid()) < _Point) ||
      (posType == OP_SELL && MathAbs(trailingStop - Ask()) < _Point))
     {
      ClosePosition();
      return;
     }

   if(MathAbs(trailingStop - posStopLoss) > _Point)
     {
      posStopLoss = NormalizeDouble(trailingStop, _Digits);
      ModifyPosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Bid(void)
  {
   return MarketInfo(_Symbol, MODE_BID);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ask(void)
  {
   return MarketInfo(_Symbol, MODE_ASK);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(const int bar)
  {
   return Time[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(const int bar)
  {
   return Open[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(const int bar)
  {
   return High[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(const int bar)
  {
   return Low[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(const int bar)
  {
   return Close[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue(void)
  {
   return _Digits == 4 || _Digits == 5 ? 0.0001
        : _Digits == 2 || _Digits == 3 ? 0.01
                        : _Digits == 1 ? 0.1 : 1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree(void)
  {
   if(IsTradeAllowed())
      return true;

   const uint startWait = GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped())
         return false;

      const uint diff = GetTickCount() - startWait;
      if(diff > 30 * 1000)
        {
         Print("The waiting limit exceeded!");
         return false;
        }

      if(IsTradeAllowed())
        {
         RefreshRates();
         return true;
        }

      Sleep(TRADE_RETRY_WAIT);
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession(void)
  {
   const int dayOfWeek    = DayOfWeek();
   const int periodStart  = int(Time(0) % 86400);
   const int periodLength = PeriodSeconds(_Period);
   const int periodFix    = periodStart + (sessionCloseAtSessionClose ? periodLength : 0);
   const int friBarFix    = periodStart + (sessionCloseAtFridayClose ||
                                           sessionCloseAtSessionClose ? periodLength : 0);

   return dayOfWeek == 0 && sessionIgnoreSunday ? true
        : dayOfWeek == 0 ? periodStart < sessionSundayOpen ||
                           periodFix   > sessionSundayClose
        : dayOfWeek  < 5 ? periodStart < sessionMondayThursdayOpen ||
                           periodFix   > sessionMondayThursdayClose
                         : periodStart < sessionFridayOpen ||
                           friBarFix   > sessionFridayClose;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose(void)
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose)
      return false;

   const int dayOfWeek = DayOfWeek();
   const int periodEnd = int(Time(0) % 86400) + PeriodSeconds(_Period);

   return dayOfWeek == 0 && sessionCloseAtSessionClose ? periodEnd > sessionSundayClose
        : dayOfWeek  < 5 && sessionCloseAtSessionClose ? periodEnd > sessionMondayThursdayClose
        : dayOfWeek == 5 ? periodEnd > sessionFridayClose : false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateAccountProtection(void)
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double maxEquity = GlobalVariableGet(accMaxEquityGlobalVarName);
   if(equity > maxEquity)
     {
      maxEquity = equity;
      GlobalVariableSet(accMaxEquityGlobalVarName, maxEquity);
     }

   equityDrawdownPercent = 100 * (maxEquity - equity) / maxEquity;

   if(equity > GlobalVariableGet(accMaxDailyEquityGlobalVarName))
      GlobalVariableSet(accMaxDailyEquityGlobalVarName, equity);

   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > GlobalVariableGet(accMaxDailyBalanceGlobalVarName))
      GlobalVariableSet(accMaxDailyBalanceGlobalVarName, balance);

   double maxDailyBalance = GlobalVariableGet(accMaxDailyBalanceGlobalVarName);
   double maxDailyEquity  = GlobalVariableGet(accMaxDailyEquityGlobalVarName);

   const datetime currentTime = TimeCurrent();
   MqlDateTime dateTime;
   TimeToStruct(currentTime, dateTime);
   if(dateTime.hour == Daily_Reset && currentTime - dailyDrawdownLastReset > 60 * 60)
     {
      dailyDrawdownLastReset = currentTime;
      GlobalVariableSet(accMaxDailyEquityGlobalVarName,  equity);
      GlobalVariableSet(accMaxDailyBalanceGlobalVarName, balance);
      GlobalVariableSet(accEntrySuspendGlobalVarName,    0);
      maxDailyBalance = balance;
      maxDailyEquity  = equity;
      entryProtectionMessage = "";
     }

   dailyLoss     = equity >= maxDailyBalance ? 0 : maxDailyBalance - equity;
   dailyDrawdown = 100 * (maxDailyEquity - equity) / maxDailyEquity;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAccountProtection(void)
  {
   const double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(Min_Equity > sigma && accountEquity <= Min_Equity)
     {
      ActivateProtection(StringFormat("Minimum equity protection activated. Equity: %.2f", accountEquity));
      return;
     }

   if(Max_Equity > sigma && accountEquity >= Max_Equity)
     {
      ActivateProtection(StringFormat("Maximum equity protection activated. Equity: %.2f", accountEquity));
      return;
     }

   if(MaxEquity_DD > sigma && equityDrawdownPercent >= MaxEquity_DD)
     {
      ActivateProtection(StringFormat("Max Equity DD protection activated! Equity DD: %.2f%%", equityDrawdownPercent));
      return;
     }

   if(MaxDailyLoss > sigma && dailyLoss >= MaxDailyLoss)
     {
      entryProtectionMessage = StringFormat("Max daily loss protection activated! Daily loss: %.2f\n", dailyLoss);
      GlobalVariableSet(accEntrySuspendGlobalVarName, 1);
      if(posType == OP_BUY || posType == OP_SELL)
         ClosePosition();
      return;
     }

   if(Max_Daily_DD > sigma && dailyDrawdown >= Max_Daily_DD)
     {
      entryProtectionMessage = StringFormat("Max daily drawdown protection activated! Daily DD: %.2f%%\n", dailyDrawdown);
      GlobalVariableSet(accEntrySuspendGlobalVarName, 1);
      if(posType == OP_BUY || posType == OP_SELL)
         ClosePosition();
      return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ActivateProtection(const string message)
  {
   if(posType == OP_BUY || posType == OP_SELL)
      ClosePosition();

   DeleteObjects();

   accountProtectionMessage  = StringFormat("\n%s\nMagic number: %d\n", robotTagline, Magic_Number);
   accountProtectionMessage += message + "\n";
   accountProtectionMessage += "The current position was closed." + "\n";
   accountProtectionMessage += "The Expert Advisor was turned off.";
   Comment(accountProtectionMessage);
   Print(accountProtectionMessage);

   Sleep(20 * 1000);
   ExpertRemove();
   OnDeinit(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetPosStats(void)
  {
   posStatCount = 0;
   posStatLots  = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      const int ordType = OrderType();
      if(ordType != OP_BUY && ordType != OP_SELL)
         continue;

      posStatCount += 1;
      posStatLots  += OrderLots();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateStats(void)
  {
   string statsInfo = StringFormat("\n%s\nMagic number: %d\n", robotTagline, Magic_Number);

   if(entryProtectionMessage != "")
      statsInfo += "\n" + entryProtectionMessage;
   if(Pos_Stat)
      statsInfo += GetPositionStats() + "\n";
   if(Robot_Stats)
      statsInfo += GetRobotStats() + "\n";
   if(Max_Spread   > sigma || Max_OpenPos > sigma || Max_OpenLots > sigma || MaxDailyLoss > sigma ||
      Max_Daily_DD > sigma || Min_Equity  > sigma || Max_Equity   > sigma || MaxEquity_DD > sigma)
      statsInfo += GetProtectionInfo();
   if(News_Priority != NewsFilter_Disabled)
      statsInfo += GetNewsText() + "\n";

   RenderStats(statsInfo);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetProtectionInfo(void)
  {
   string protectionInfo = "\n            ..:: Active Protections ::..\n";

   if(Max_Spread > sigma)
      protectionInfo += StringFormat("Max spread: %d, current: %d\n",
                                     Max_Spread, (int)MathRound((Ask() - Bid()) / _Point));
   if(Max_OpenPos > sigma)
      protectionInfo += StringFormat("Max open positions: %d, current: %d\n",
                                     Max_OpenPos, posStatCount);
   if(Max_OpenLots > sigma)
      protectionInfo += StringFormat("Max open lots: %.2f, current: %.2f\n",
                                     Max_OpenLots, posStatLots);
   if(MaxDailyLoss > sigma)
      protectionInfo += StringFormat("Max daily loss: %d, current: %.2f\n",
                                     MaxDailyLoss, dailyLoss);
   if(Max_Daily_DD > sigma)
      protectionInfo += StringFormat("Max daily drawdown: %.2f%%, current: %.2f%%\n",
                                     Max_Daily_DD, dailyDrawdown);
   if(Min_Equity > sigma)
      protectionInfo += StringFormat("Min equity: %d, current: %.2f\n",
                                     Min_Equity, AccountInfoDouble(ACCOUNT_EQUITY));
   if(MaxEquity_DD > sigma)
      protectionInfo += StringFormat("Max equity drawdown: %.2f%%, current: %.2f%%\n",
                                     MaxEquity_DD, equityDrawdownPercent);
   if(Max_Equity > sigma)
      protectionInfo += StringFormat("Max equity: %d, current: %.2f\n",
                                     Max_Equity, AccountInfoDouble(ACCOUNT_EQUITY));

   return protectionInfo;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetPositionStats(void)
  {
   const string positionStats = "\n            ..:: Position Stats ::..\n";

   if(posType == OP_FLAT)
      return positionStats +  "Position: no open position";

   return positionStats +
          StringFormat("Position: %s, Lots: %.2f, Profit %.2f\n",
                       (posType == OP_BUY) ? "Long" : "Short",
                       posLots, posProfit) +
          StringFormat("Open price: %s, Current price: %s\n",
                       DoubleToString(posPriceOpen, _Digits),
                       DoubleToString(posPriceCurr, _Digits)) +
          StringFormat("Stop Loss: %s, Take Profit: %s",
                       DoubleToString(posStopLoss,   _Digits),
                       DoubleToString(posTakeProfit, _Digits));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetRobotStats(void)
  {
   return "\n            ..:: Trading Stats ::..\n" +
          "  1-day: " + GetRobotStatsDays(1) + "\n" +
          "  7-day: " + GetRobotStatsDays(7) + "\n" +
          "30-day: "  + GetRobotStatsDays(30);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetRobotStatsDays(const int days)
  {
   double grossProfit     = 0;
   double grossLoss       = 0;
   int    histDealsCnt    = 0;
   double histDealsProfit = 0;

   const datetime timeCurrent = TimeCurrent();
   const datetime timeStart   = timeCurrent - days*PeriodSeconds(PERIOD_D1);
   const int      deals       = OrdersHistoryTotal();

   for(int i = 0; i < deals; i += 1)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderCloseTime() < timeStart)
         continue;

      // When we close a position manually it gets orderMagic = 0
      const long orderMagic = OrderMagicNumber();
      if(orderMagic > 0 && orderMagic != Magic_Number)
         continue;

      if(OrderSymbol() != _Symbol)
         continue;

      const int ordType = OrderType();
      if(ordType != OP_BUY && ordType != OP_SELL)
         continue;

      const double profit = OrderProfit() + OrderSwap() + OrderCommission();

      histDealsProfit += profit;
      histDealsCnt    += 1;

      if(profit > sigma)
         grossProfit += profit;
      if(profit < -sigma)
         grossLoss -= profit;
     }

   const double profitFactor = grossLoss > sigma ? grossProfit / grossLoss : grossProfit;

   return StringFormat("Trades: %d, Profit: %.2f, Profit factor: %.2f",
                       histDealsCnt, histDealsProfit, profitFactor);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetNewsInfo(void)
  {
   return "";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderStats(const string text)
  {
   string lines[];
   const int linesCount = StringSplit(text, '\n', lines);

   int lineWidth, lineHeight;
   TextGetSize(robotTagline, lineWidth, lineHeight);

   if(maxRectangles == 0)
      RectLabelCreate(0, "Stats_background", 0, 0, 30, lineWidth,
                      linesCount * lineHeight, GetChartBackColor(0));

   const color foreColor = GetChartForeColor(0);
   for(int i = 0; i < linesCount; i += 1)
     {
      if(lines[i] == "")
         lines[i] = " ";
      string labelName = "label" + IntegerToString(i);
      if(i < maxLabels)
         LabelUpdate(0, labelName, lines[i]);
      else
         LabelCreate(0, labelName, 0, 10, 20 + i * lineHeight,
                     CORNER_LEFT_UPPER, lines[i], "Arial", 10, foreColor);

      int lnWidth, lnHeight;
      TextGetSize(lines[i], lnWidth, lnHeight);
      if(lnWidth > lineWidth)
         lineWidth = lnWidth;
     }
   ObjectSetInteger(0, "Stats_background", OBJPROP_XSIZE,
                    (int) MathRound(lineWidth * 0.90));
   ObjectSetInteger(0, "Stats_background", OBJPROP_YSIZE,
                    linesCount * lineHeight);
   for(int i = linesCount; i < maxLabels; i += 1)
      LabelUpdate(0, "label" + IntegerToString(i), " ");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RectLabelCreate(
   const long             chartId    = 0,                 // chart's ID
   const string           name       = "RectLabel",       // label name
   const int              sub_window = 0,                 // sub-window index
   const int              x          = 0,                 // X coordinate
   const int              y          = 0,                 // Y coordinate
   const int              width      = 50,                // width
   const int              height     = 18,                // height
   const color            back_clr   = clrBlack,          // background color
   const ENUM_BORDER_TYPE border     = BORDER_SUNKEN,     // border type
   const ENUM_BASE_CORNER corner     = CORNER_LEFT_UPPER, // chart corner for anchoring
   const color            clr        = clrBlack,          // flat border color (Flat)
   const ENUM_LINE_STYLE  style      = STYLE_SOLID,       // flat border style
   const int              line_width = 0,                 // flat border width
   const bool             back       = false,             // in the background
   const bool             selection  = false,             // highlight to move
   const bool             hidden     = true,              // hidden in the object list
   const long             z_order    = 0)                 // priority for mouse click
  {
   if(!ObjectCreate(chartId, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0)) return;
   maxRectangles += 1;
   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(chartId, name, OBJPROP_XSIZE,       width);
   ObjectSetInteger(chartId, name, OBJPROP_YSIZE,       height);
   ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,     back_clr);
   ObjectSetInteger(chartId, name, OBJPROP_BORDER_TYPE, border);
   ObjectSetInteger(chartId, name, OBJPROP_CORNER,      corner);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR,       clr);
   ObjectSetInteger(chartId, name, OBJPROP_STYLE,       style);
   ObjectSetInteger(chartId, name, OBJPROP_WIDTH,       line_width);
   ObjectSetInteger(chartId, name, OBJPROP_BACK,        back);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE,  selection);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTED,    selection);
   ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,      hidden);
   ObjectSetInteger(chartId, name, OBJPROP_ZORDER,      z_order);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LabelCreate(
   const long              chartId=0,                // chart's ID
   const string            name="Label",             // label name
   const int               sub_window=0,             // sub-window index
   const int               x=0,                      // X coordinate
   const int               y=0,                      // Y coordinate
   const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
   const string            text="Label",             // text
   const string            font="Arial",             // font
   const int               font_size=10,             // font size
   const color             clr=clrYellow,            // color
   const double            angle=0.0,                // text slope
   const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
   const bool              back=false,               // in the background
   const bool              selection=false,          // highlight to move
   const bool              hidden=true,              // hidden in the object list
   const long              z_order=0)                // priority for mouse click
  {
   if(!ObjectCreate(chartId, name, OBJ_LABEL, sub_window, 0 , 0)) return;
   maxLabels += 1;
   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(chartId, name, OBJPROP_CORNER,     corner);
   ObjectSetString( chartId, name, OBJPROP_TEXT,       text);
   ObjectSetString( chartId, name, OBJPROP_FONT,       font);
   ObjectSetString( chartId, name, OBJPROP_TOOLTIP,    "\n");
   ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,   font_size);
   ObjectSetDouble( chartId, name, OBJPROP_ANGLE,      angle);
   ObjectSetInteger(chartId, name, OBJPROP_ANCHOR,     anchor);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(chartId, name, OBJPROP_BACK,       back);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTED,   selection);
   ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     hidden);
   ObjectSetInteger(chartId, name, OBJPROP_ZORDER,     z_order);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LabelUpdate(int chartId, string name, string text)
  {
   ObjectSetString(chartId, name, OBJPROP_TEXT, text);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color GetChartForeColor(const long chartId=0)
  {
   long foreColor = clrWhite;
   ChartGetInteger(chartId, CHART_COLOR_FOREGROUND, 0, foreColor);
   return (color) foreColor;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color GetChartBackColor(const long chartId=0)
  {
   long backColor = clrBlack;
   ChartGetInteger(chartId, CHART_COLOR_BACKGROUND, 0, backColor);
   return (color) backColor;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteObjects(void)
  {
   if(ObjectFind(0, "Stats_background") == 0)
      ObjectDelete(0, "Stats_background");
   maxLabels = MathMax(maxLabels, 100);
   for(int i = 0; i < maxLabels; i++)
     {
      const string objName = "label" + IntegerToString(i);
      if(ObjectFind(0, objName) == 0)
         ObjectDelete(0, objName);
     }
   maxRectangles = 0;
   maxLabels     = 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitGlobalVariables(void)
  {
   if(MQLInfoInteger(MQL_TESTER)) return;

   const string accountNumberText = (string)AccountInfoInteger(ACCOUNT_LOGIN);

   accMaxEquityGlobalVarName       = "Max_Equity_"         + accountNumberText;
   accMaxDailyBalanceGlobalVarName = "Max_Daily_Balance_"  + accountNumberText;
   accMaxDailyEquityGlobalVarName  = "Max_Daily_Equity_"   + accountNumberText;
   accEntrySuspendGlobalVarName    = "Is_Entry_Suspended_" + accountNumberText;

   if(!GlobalVariableCheck(accMaxEquityGlobalVarName))
      GlobalVariableSet(accMaxEquityGlobalVarName, AccountInfoDouble(ACCOUNT_EQUITY));
   if(!GlobalVariableCheck(accMaxDailyBalanceGlobalVarName))
      GlobalVariableSet(accMaxDailyBalanceGlobalVarName, AccountInfoDouble(ACCOUNT_BALANCE));
   if(!GlobalVariableCheck(accMaxDailyEquityGlobalVarName))
      GlobalVariableSet(accMaxDailyEquityGlobalVarName, AccountInfoDouble(ACCOUNT_EQUITY));
   if(!GlobalVariableCheck(accEntrySuspendGlobalVarName))
      GlobalVariableSet(accEntrySuspendGlobalVarName, 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadNews(void)
  {
   loadNewsError = "";
   string error = "";
   const string newsContent = GetNewsContent(error);
   if(error != "")
     {
      loadNewsError = error;
      return;
     }

   if(newsContent == "")
     {
      loadNewsError = StringFormat("Cannot load news. Last error code: %d", GetLastError());
      return;
     }

   ParseNewsContent(newsContent, error);

   if(error != "")
      loadNewsError = error;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseNewsContent(const string newsContent, string &error)
  {
   string lines[];
   const int linesLen = StringSplit(newsContent, '\n', lines);

   if(linesLen == -1)
     {
      error = "Cannot parse the news feed";
      return;
     }

   ArrayResize(newsRecords, linesLen);

   for(int i = 0; i < linesLen; i += 1)
     {
      string fields[];
      const int fieldsLen = StringSplit(lines[i], ';', fields);

      if(fieldsLen != 4)
        {
         error = "Cannot parse the news feed records";
         return;
        }

      NewsRecord record;
      record.time     = (datetime) StringToInteger(fields[0]);
      record.priority = fields[1];
      record.currency = fields[2];
      record.title    = fields[3];

      newsRecords[i] = record;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetNewsContent(string &error)
  {
   const string url = "https://forexsb.com/updates/news-feed.txt";

   char   reqBody[], resData[];
   string headers;

   ResetLastError();

   const int resCode  = WebRequest("GET", url, "", 10000, reqBody, resData, headers);
   const int resError = GetLastError();

   isNewsFeedOk = false;
   if(resError == ERR_FUNCTION_NOT_CONFIRMED)
     {
      error = "News Filter cannot access the news server.\n" +
              "Follow these steps to fix it:\n"
              " - open the \"Tool\" -> \"Options\" panel\n" +
              " - go to the \"Expert Advisors\" tab\n" +
              " - enable the \"Allow WebRequest for the listed URL:\" option.\n" +
              " - add \"https://forexsb.com\" in a field below.";
      return "";
     }

   if(resError != ERR_NO_MQLERROR)
     {
      error = StringFormat("News Filter connection error! Error code: %d", resError);
      return "";
     }

   if(resCode != 200)
     {
      error = StringFormat("Response code: %d", resCode);
      return "";
     }

   isNewsFeedOk = true;
   return CharArrayToString(resData, 0, ArraySize(resData), CP_UTF8);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetNewsText(void)
  {
   string newsText = "\n            ..:: Upcoming News ::..\n";
   if(loadNewsError != "") return newsText + loadNewsError;

   const datetime timeNow   = TimeGMT();
   const datetime timeShift = (datetime) MathRound((TimeLocal() - timeNow) / 3600.0) * 3600;
   const int      newsCount = ArraySize(newsRecords);

   for(int i = 0, count = 0; i < newsCount && count < News_ViewCount; i++)
     {
      const NewsRecord newsRecord = newsRecords[i];

      if(newsRecord.time < timeNow - News_AfterHigh * 60 ||
         !NewsIsAcceptedCurrency(newsRecord) ||
         !NewsIsAcceptedPriority(newsRecord))
         continue;

      const string newLine  = count > 0 ? "\n" : "";
      const string newsTime = TimeToString(newsRecord.time + timeShift, TIME_DATE | TIME_MINUTES);
      const string priority = newsRecord.priority == "high" ? "[high]" : "[med]";
      const string text     = StringFormat("%s%s %s %s %s", newLine, priority, newsTime,
                                           newsRecord.currency, newsRecord.title);
      StringAdd(newsText, text);
      count += 1;
     }

   return newsText;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewsIsAcceptedCurrency(const NewsRecord &newsRecord)
  {
   for(int i = 0; i < ArraySize(newsCurrencies); i++)
      if(newsCurrencies[i] == newsRecord.currency)
         return true;

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewsIsAcceptedPriority(const NewsRecord &newsRecord)
  {
   return (News_Priority == NewsFilter_HighAndMedium) ||
          (News_Priority == NewsFilter_HighOnly && newsRecord.priority == "high");
  }
//+------------------------------------------------------------------+
//| Gets the index of an active news or -1                           |
//+------------------------------------------------------------------+
int NewsFilterActive(void)
  {
   if(News_Priority == NewsFilter_Disabled)
      return -1;

   const datetime timeUtc = TimeGMT();
   const int      newsLen = ArraySize(newsRecords);
   for(int i = 0; i < newsLen; i++)
     {
      const NewsRecord news = newsRecords[i];
      if(!NewsIsAcceptedCurrency(news) || !NewsIsAcceptedPriority(news))
         continue;

      if(news.priority == "high" &&
         news.time - News_BeforeHigh * 60 - 15 <= timeUtc &&
         news.time + News_AfterHigh  * 60 - 15 >= timeUtc)
         return i;

      if(news.priority == "medium" &&
         news.time - News_BeforeMedium * 60 - 15 <= timeUtc &&
         news.time + News_AfterMedium  * 60 - 15 >= timeUtc)
         return i;
     }

   return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseNewsCurrenciesText(void)
  {
   string parts[], parsed[];
   const int partsLen = StringSplit(News_Currencies, ',', parts);
   ArrayResize(parsed, partsLen);
   int len = 0;
   for(int i = 0; i < partsLen; i++)
     {
      string part = parts[i];
      StringReplace(part, " ", "");
      if(StringLen(part) > 0)
        {
         parsed[i] = part;
         len += 1;
        }
     }

   ArrayResize(newsCurrencies, len);
   for(int i = 0; i < len; i += 1)
      newsCurrencies[i] = parsed[i];
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET Eightcap; USDJPY; M15 */
/*STRATEGY CODE {"properties":{"entryLots":0.65,"tradeDirectionMode":0,"oppositeEntrySignal":0,"stopLoss":42,"takeProfit":90,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Directional Indicators","listIndexes":[0,0,0,0,0],"numValues":[23,0,0,0,0,0]},{"name":"Bulls Power","listIndexes":[2,0,0,0,0],"numValues":[29,0,0,0,0,0]}],"closeFilters":[{"name":"Candle Color","listIndexes":[1,0,0,0,0],"numValues":[28,3,0,0,0,0]}]} */
