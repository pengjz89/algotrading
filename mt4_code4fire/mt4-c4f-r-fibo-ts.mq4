//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                    Fibonacci.mq4 |
//|                                                        Code4FIRE |
//|                        Reversal Fibo Strategy with Trailing Stop |
//+------------------------------------------------------------------+
#property copyright "C4F-R-FIBO-TS"
#property link      ""
#property version   "1.02"


//--Input Variables in Expert Advisor
input double   input_lots                    = 0.01;         // starting lot
input ushort   input_stop_loss               = 33;           // stop loss, in pips (1.00045-1.00055=1 pips)
input ushort   input_take_profit             = 48;           // take profit, in pips (1.00045-1.00055=1 pips)

input ushort   input_trailingstop            = 38;           //trailing stop
input ushort   input_trailingstep            = 42;           //trailing step

input double   input_trailing_max_lots       = 0.02;        // trailing maximum lots
input int      input_magicnumber             = 1111;        // magic number

//input bool                 input_closebyposition         = false;

//-- Symbol and Timeframe in Expert Advisor
ENUM_TIMEFRAMES   m_time_frame;                             //variable for storing the time frame
string            m_ptradecomment = "C4F-R-Fibo-TS:";
string            m_tradecomment = "";

double            m_trade_stop_loss = 0;                         //variable for stoploss
double            m_trade_take_profit = 0;                       //variable for take profit
double            m_lots = 0.01;
double            m_trade_trailingstop=0.0;                       //variable for trailing stop
double            m_trade_trailingstep=0.0;

//ulong             m_tradeslippage=0;

double            fibo_lots[15];

//--Position Variable
string close_comment_timeinterval = "timeinterval";
string close_comment_stop_loss = "stoploss";
string close_comment_take_profit = "takeprofit";

int LastBars = 0;
int MyDigits;
double MyPoint;
extern int Slippage = 100; 	// Tolerated slippage in brokers' pips

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {

//-- Time Period for trading
   m_time_frame=Period();                               //save the current time frame of the chart for further operation of the EA on this very time frame

//-- Initialize Take Profit and Stop Loss Pricing
   int digits_adjust=1;
  
  if(Digits==5)MyDigits=4;
  else if(Digits==3)MyDigits=2;
  else MyDigits = Digits; 
  if (Point == 0.00001) MyPoint = 0.0001; //6 digits
  else if (Point == 0.001) MyPoint = 0.01; //3 digits (for Yen based pairs)
  else MyPoint = Point; //Normal
   
   m_trade_stop_loss       = input_stop_loss        * MyPoint;
   m_trade_take_profit     = input_take_profit      * MyPoint;
   m_trade_trailingstop    = input_trailingstop     * MyPoint;
   m_trade_trailingstep    = input_trailingstep     * MyPoint;

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

   add_fibo_lots_value();

   double history_deal_volume = 0.00;
   double history_deal_profit = 0.00;
//Last Deal - Open Trade
   ulong history_deal_entry_in_ticket = 0;
//Last Deal - Close Trade
   ulong history_deal_entry_out_ticket = 0;

   int history_deal_deal_type = NULL;

   if(!checkForOpenPosition())
   {
      int totalHistoryDeals = OrdersHistoryTotal();
      if(totalHistoryDeals <= 1)
      {
         //This is for first trade
        open_position(OP_SELL);
        return;
      }
      else
      {

        for(int i=totalHistoryDeals; i>=0; i--)   {
          if(OrderSymbol () != Symbol()) continue;
          if(OrderMagicNumber() == input_magicnumber && OrderSymbol() == Symbol())  {                
            history_deal_profit = OrderProfit();
            Print("history | deal profit: " + history_deal_profit);
            history_deal_volume = OrderLots();
            Print("history | deal volume: " + history_deal_volume);
            history_deal_deal_type = OrderType();
            Print("history | deal type: " + history_deal_deal_type);
            Print("history | deal number: " + i);
            break;
          }
        }

         Comment(m_ptradecomment + "|hvol:" + history_deal_volume + "|htype:" + history_deal_deal_type + "|hprofit: " + history_deal_profit);

         if(history_deal_profit>0)  {
            m_lots = input_lots;
            if(history_deal_deal_type == OP_BUY)   {
               m_tradecomment = m_ptradecomment + "TP:M_BUY";
               open_position(OP_BUY);
            }
            else  {
               m_tradecomment = m_ptradecomment + "TP:M_SELL";
               open_position(OP_SELL);
            }
         }
         else  {
            int fibo_lots_count = ArrayBsearch(fibo_lots, history_deal_volume);
            if(fibo_lots_count < 15)   {
               fibo_lots_count = fibo_lots_count + 1;
            }
            m_lots = fibo_lots[fibo_lots_count];
            
            if(history_deal_deal_type == OP_BUY)   {
               m_tradecomment = m_ptradecomment + "SL:R_SELL";
               open_position(OP_SELL);
            }
            else  {
               m_tradecomment = m_ptradecomment + "SL:R_BUY";
               open_position(OP_BUY);
            }
           }
        }
     }
    else  {
      runTrailingStepNStop();
    }
   return;
  }

//+------------------------------------------------------------------+
//| Fibo Lots for Incremental Reversal                               |
//+------------------------------------------------------------------+
void add_fibo_lots_value()
  {
   fibo_lots[0] = 0.01;
   fibo_lots[1] = 0.02;
   fibo_lots[2] = 0.03;
   fibo_lots[3] = 0.05;
   fibo_lots[4] = 0.08;
   fibo_lots[5] = 0.13;
   fibo_lots[6] = 0.21;
   fibo_lots[7] = 0.34;
   fibo_lots[8] = 0.55;
   fibo_lots[9] = 0.89;
   fibo_lots[10] = 1.44;
   fibo_lots[11] = 2.33;
   fibo_lots[12] = 3.77;
   fibo_lots[13] = 6.10;
   fibo_lots[14] = 9.87;
//fibo_lots[15] = 15.97;
//fibo_lots[16] = 25.84;
//fibo_lots[17] = 41.81;

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
//| Run Trailing Stop/Step                                           |
//+------------------------------------------------------------------+
void runTrailingStepNStop()
  {

    // Trade only if new bar has arrived
    if (LastBars != Bars) LastBars = Bars;
    else return(0);

    for(int i=OrdersTotal()-1; i>=0; i--)
    {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))  continue;
      if(OrderMagicNumber() != input_magicnumber && OrderSymbol() != Symbol()) continue;
      
      double current_eval = 0.0;
      double current_stoploss=0.0;
      double current_priceopen=0.0;
      bool res = false;
      if(OrderLots() <= input_trailing_max_lots)
      {
        if(OrderType()==OP_BUY)
        {
          double current_bid = Bid;
          current_eval=current_bid-m_trade_trailingstep-m_trade_trailingstop;
          current_stoploss=OrderStopLoss();
          current_priceopen=OrderOpenPrice();
          if(current_eval>current_priceopen)
          {
            double updated_buy_stoploss=current_bid-m_trade_trailingstop;
            double current_buy_takeprofit=OrderTakeProfit();

            if(updated_buy_stoploss < OrderStopLoss())
            {
              updated_buy_stoploss = OrderStopLoss();
            }

            res=OrderModify(OrderTicket(),OrderOpenPrice(),updated_buy_stoploss,current_buy_takeprofit,0,Blue);
            if(!res)
               Print("Error in OrderModify. Error code=",GetLastError());
            else
               Print("Order modified successfully.");
          }
          return;
        }

        if(OrderType()==OP_SELL)
        {
          double current_ask = Ask;
          current_eval=current_ask-m_trade_trailingstep-m_trade_trailingstop;
          current_stoploss=OrderStopLoss();
          current_priceopen=OrderOpenPrice();
          if(current_eval>current_priceopen)
          {
            double updated_sell_stoploss=current_ask-m_trade_trailingstop;
            double current_sell_takeprofit=OrderTakeProfit();

            if(updated_sell_stoploss < OrderStopLoss())
            {
              updated_sell_stoploss = OrderStopLoss();
            }

            res=OrderModify(OrderTicket(),OrderOpenPrice(),updated_sell_stoploss,current_sell_takeprofit,0,Blue);
            if(!res)
               Print("Error in OrderModify. Error code=",GetLastError());
            else
               Print("Order modified successfully.");
          }
          return;
        }
      }
    }
   return;
  }

//+------------------------------------------------------------------+
//| Check for New Bar                                                |
//+------------------------------------------------------------------+
bool is_new_bar()
{
  static datetime lastbar;
  datetime curbar = Time[0];
  if(lastbar!=curbar)
  {
    lastbar=curbar;
    return (true);
  }
  else
  {
    return(false);
  }
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

    ticket = OrderSend(Symbol(),pos_type,m_lots,ask_price,Slippage,stop_loss_level,take_profit_level,m_tradecomment,input_magicnumber,0,Green);
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

    ticket = OrderSend(Symbol(),pos_type,m_lots,bid_price,Slippage,stop_loss_level,take_profit_level,m_tradecomment,input_magicnumber,0,Red);
    //m_trade.Sell(m_lots,NULL,bid_price,stop_loss_level,take_profit_level,m_tradecomment);
    if(ticket<0)
    {
      Print("OrderSend failed with error #",GetLastError());
    }
    else
      Print("OrderSend placed successfully #",ticket);
  }  
}

