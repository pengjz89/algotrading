//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                mt4-c4f-ha-ts.mq4 |
//|                                                        Code4FIRE |
//|                          Heiken Ashi Strategy with Trailing Stop |
//+------------------------------------------------------------------+
#property copyright "C4F-HA-TS"
#property link      ""
#property version   "1.02"


//--Input Variables in Expert Advisor
input double   input_lots                    = 0.01;         // starting lot
input ushort   input_stop_loss               = 0;           // stop loss, in pips (1.00045-1.00055=1 pips)
input ushort   input_take_profit             = 0;           // take profit, in pips (1.00045-1.00055=1 pips)

input ushort   input_trailingstop            = 0;           //trailing stop
input ushort   input_trailingstep            = 0;           //trailing step

input int      input_magicnumber             = 2222;        // magic number

//input bool                 input_closebyposition         = false;

//-- Symbol and Timeframe in Expert Advisor
string            m_ptradecomment = "C4F-HA-TS:";
string            m_tradecomment = "";

double            m_trade_stop_loss = 0;                         //variable for stoploss
double            m_trade_take_profit = 0;                       //variable for take profit
double            m_lots = 0.01;
double            m_trade_trailingstop=0.0;                       //variable for trailing stop
double            m_trade_trailingstep=0.0;

//--Position Variable
string close_comment_timeinterval = "timeinterval";
string close_comment_stop_loss = "stoploss";
string close_comment_take_profit = "takeprofit";

int MyDigits;
double MyPoint;

// Global variables
// Common
int LastBars = 0;
bool HaveLongPosition;
bool HaveShortPosition;
extern int Slippage = 100; 	// Tolerated slippage in brokers' pips

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {

//-- Initialize Take Profit and Stop Loss Pricing
   int digits_adjust=1;
  
  if(Digits==5)MyDigits=4;
  else if(Digits==3)MyDigits=2;
  else MyDigits = Digits; 
  if (Point == 0.00001) MyPoint = 0.0001; //6 digits
  else if (Point == 0.001) MyPoint = 0.01; //3 digits (for Yen based pairs)
  else MyPoint = Point; //Normal
   
   m_lots                  = input_lots;

   return(0);                                               //return 0, initialization complete
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

  if ((!IsTradeAllowed()) || (IsTradeContextBusy()) || (!IsConnected()) || ((!MarketInfo(Symbol(), MODE_TRADEALLOWED)) && (!IsTesting()))) return(0);


	// Trade only if new bar has arrived
	if (LastBars != Bars) LastBars = Bars;
	else return(0);
   
   // Close conditions   
   bool BearishClose = false;
   bool BullishClose = false;
   
   // Signals
   bool Bullish = false;
   bool Bearish = false;

   // Heiken Ashi indicator values
   double HAOpenLatest, HAOpenPrevious, HACloseLatest, HAClosePrevious, HAHighLatest, HALowLatest;

   HAOpenLatest = iCustom(NULL, 0, "Heiken Ashi", 2, 1);
   HAOpenPrevious = iCustom(NULL, 0, "Heiken Ashi", 2, 2);
   HACloseLatest = iCustom(NULL, 0, "Heiken Ashi", 3, 1);
   HAClosePrevious = iCustom(NULL, 0, "Heiken Ashi", 3, 2);
   if (HAOpenLatest >= HACloseLatest) HAHighLatest = iCustom(NULL, 0, "Heiken Ashi", 0, 1);
   else HAHighLatest = iCustom(NULL, 0, "Heiken Ashi", 1, 1);
   if (HAOpenLatest >= HACloseLatest) HALowLatest = iCustom(NULL, 0, "Heiken Ashi", 1, 1);
   else HALowLatest = iCustom(NULL, 0, "Heiken Ashi", 0, 1);
   
   // REVERSED!!!
   
   // Close signals
   // Bullish HA candle, current has no lower wick, previous also bullish
   if ((HAOpenLatest < HACloseLatest) && (HALowLatest == HAOpenLatest) && (HAOpenPrevious < HAClosePrevious))
   {
      BullishClose = true;
   }
   // Bearish HA candle, current has no upper wick, previous also bearish
   else if ((HAOpenLatest > HACloseLatest) && (HAHighLatest == HAOpenLatest) && (HAOpenPrevious > HAClosePrevious))
   {
      BearishClose = true;
   }

   // Sell entry condition
   // Bullish HA candle, and body is longer than previous body, previous also bullish, current has no lower wick
   if ((HAOpenLatest < HACloseLatest) && (HACloseLatest - HAOpenLatest > MathAbs(HAClosePrevious - HAOpenPrevious)) && (HAOpenPrevious < HAClosePrevious) && (HALowLatest == HAOpenLatest))
   {
      Bullish = false;
      Bearish = true;
   }
   // Buy entry condition
   // Bearish HA candle, and body is longer than previous body, previous also bearish, current has no upper wick
   else if ((HAOpenLatest > HACloseLatest) && (HAOpenLatest - HACloseLatest > MathAbs(HAClosePrevious - HAOpenPrevious)) && (HAOpenPrevious > HAClosePrevious) && (HAHighLatest == HAOpenLatest))
   {
      Bullish = true;
      Bearish = false;
   }
   else
   {
      Bullish = false;
      Bearish = false;
   }
   
   GetPositionStates();
   
   if ((HaveShortPosition) && (BearishClose)) ClosePrevious();
   if ((HaveLongPosition) && (BullishClose)) ClosePrevious();

   if (Bullish)
   {
      if (!HaveLongPosition) open_position(OP_BUY);
   }
   else if (Bearish)
   {
      if (!HaveShortPosition) open_position(OP_SELL);
   }
   return(0);

   
  }

//+------------------------------------------------------------------+
//| Check for Open Position                                          |
//+------------------------------------------------------------------+
bool checkForOpenPosition()
{
   for(int i=OrdersTotal()-1; i>=0; i--)           
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))  continue;
      if(OrderMagicNumber() != input_magicnumber) continue;
      return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//|  Open Position                                                   |
//+------------------------------------------------------------------+
void open_position(int pos_type)
{
  RefreshRates();
  double stop_loss_level=0.0;
  double take_profit_level=0.0;

  int ticket = 0;
  if(pos_type==OP_BUY)
  {
    double ask_price = Ask;
    stop_loss_level=NormalizeDouble(ask_price-m_trade_stop_loss,Digits);
    take_profit_level=NormalizeDouble(ask_price+m_trade_take_profit,Digits);

    ticket = OrderSend(Symbol(),pos_type,m_lots,ask_price,Slippage,0,0,m_tradecomment,input_magicnumber,0,Green);
    if(ticket<0)
      {
        Print("OrderSend failed with error #",GetLastError());
      }
    else
        Print("OrderSend placed successfully #",ticket);

  }
  if(pos_type==OP_SELL)
  {

    double bid_price = Bid;
    stop_loss_level=NormalizeDouble(bid_price+m_trade_stop_loss,Digits);
    take_profit_level=NormalizeDouble(bid_price-m_trade_take_profit,Digits);

    ticket = OrderSend(Symbol(),pos_type,m_lots,bid_price,Slippage,0,0,m_tradecomment,input_magicnumber,0,Red);
    //m_trade.Sell(m_lots,NULL,bid_price,stop_loss_level,take_profit_level,m_tradecomment);
    if(ticket<0)
    {
      Print("OrderSend failed with error #",GetLastError());
    }
    else
      Print("OrderSend placed successfully #",ticket);
  }  
}

//+------------------------------------------------------------------+
//| Close previous position                                          |
//+------------------------------------------------------------------+
void ClosePrevious()
{
   int total = OrdersTotal();
   for (int i = 0; i < total; i++)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false) continue;
      if ((OrderSymbol() == Symbol()) && (OrderMagicNumber() == input_magicnumber))
      {
         if (OrderType() == OP_BUY)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Bid, Slippage);
         }
         else if (OrderType() == OP_SELL)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Ask, Slippage);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check what position is currently open										|
//+------------------------------------------------------------------+
void GetPositionStates()
{
   int total = OrdersTotal();
   for (int cnt = 0; cnt < total; cnt++)
   {
      if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == false) continue;
      if (OrderMagicNumber() != input_magicnumber) continue;
      if (OrderSymbol() != Symbol()) continue;

      if (OrderType() == OP_BUY)
      {
			HaveLongPosition = true;
			HaveShortPosition = false;
			return;
		}
      else if (OrderType() == OP_SELL)
      {
			HaveLongPosition = false;
			HaveShortPosition = true;
			return;
		}
	}
   HaveLongPosition = false;
	HaveShortPosition = false;
}