// File: HelperFunctions.mqh

string TradeTransactionTypeToString(int type)
{
    switch (type)
    {
        case TRADE_TRANSACTION_ORDER_ADD: return "ORDER_ADD";
        case TRADE_TRANSACTION_ORDER_UPDATE: return "ORDER_UPDATE";
        case TRADE_TRANSACTION_ORDER_DELETE: return "ORDER_DELETE";
        case TRADE_TRANSACTION_DEAL_ADD: return "DEAL_ADD";
        case TRADE_TRANSACTION_DEAL_UPDATE: return "DEAL_UPDATE";
        case TRADE_TRANSACTION_HISTORY_ADD: return "HISTORY_ADD";
        case TRADE_TRANSACTION_HISTORY_UPDATE: return "HISTORY_UPDATE";
        default: return "UNKNOWN";
    }
}

string OrderTypeToString(int type)
{
    switch (type)
    {
        case ORDER_TYPE_BUY: return "BUY";
        case ORDER_TYPE_SELL: return "SELL";
        case ORDER_TYPE_BUY_LIMIT: return "BUY_LIMIT";
        case ORDER_TYPE_SELL_LIMIT: return "SELL_LIMIT";
        case ORDER_TYPE_BUY_STOP: return "BUY_STOP";
        case ORDER_TYPE_SELL_STOP: return "SELL_STOP";
        case ORDER_TYPE_BUY_STOP_LIMIT: return "BUY_STOP_LIMIT";
        case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
        default: return "UNKNOWN";
    }
}

string OrderStateToString(int state)
{
    switch (state)
    {
        case ORDER_STATE_STARTED: return "STARTED";
        case ORDER_STATE_PLACED: return "PLACED";
        case ORDER_STATE_CANCELED: return "CANCELED";
        case ORDER_STATE_PARTIAL: return "PARTIAL";
        case ORDER_STATE_FILLED: return "FILLED";
        case ORDER_STATE_REJECTED: return "REJECTED";
        case ORDER_STATE_EXPIRED: return "EXPIRED";
        default: return "UNKNOWN";
    }
}

string DealTypeToString(int type)
{
    switch (type)
    {
        case DEAL_TYPE_BUY: return "BUY";
        case DEAL_TYPE_SELL: return "SELL";
        case DEAL_TYPE_BALANCE: return "BALANCE";
        case DEAL_TYPE_CREDIT: return "CREDIT";
        case DEAL_TYPE_CHARGE: return "CHARGE";
        case DEAL_TYPE_CORRECTION: return "CORRECTION";
        case DEAL_TYPE_BONUS: return "BONUS";
        case DEAL_TYPE_COMMISSION: return "COMMISSION";
        case DEAL_TYPE_COMMISSION_DAILY: return "COMMISSION_DAILY";
        case DEAL_TYPE_COMMISSION_MONTHLY: return "COMMISSION_MONTHLY";
        case DEAL_TYPE_COMMISSION_AGENT_DAILY: return "COMMISSION_AGENT_DAILY";
        case DEAL_TYPE_COMMISSION_AGENT_MONTHLY: return "COMMISSION_AGENT_MONTHLY";
        case DEAL_TYPE_INTEREST: return "INTEREST";
        case DEAL_TYPE_BUY_CANCELED: return "BUY_CANCELED";
        case DEAL_TYPE_SELL_CANCELED: return "SELL_CANCELED";
        default: return "UNKNOWN";
    }
}

string TimeTypeToString(int timeType)
{
    switch (timeType)
    {
        case ORDER_TIME_GTC: return "GTC";
        case ORDER_TIME_DAY: return "DAY";
        case ORDER_TIME_SPECIFIED: return "SPECIFIED";
        case ORDER_TIME_SPECIFIED_DAY: return "SPECIFIED_DAY";
        default: return "UNKNOWN";
    }
}
