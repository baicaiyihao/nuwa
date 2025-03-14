module nuwa_framework::balance_provider {
    use std::vector;                         // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::type_info;               // 导入 MoveOS 标准库中的类型信息模块
    use moveos_std::object::{Object};        // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::decimal_value::{Self, DecimalValue};  // 导入 MoveOS 标准库中的十进制值模块，并引入 DecimalValue 类型
    use rooch_framework::coin;               // 导入 Rooch 框架中的代币模块
    use rooch_framework::account_coin_store;  // 导入 Rooch 框架中的账户代币存储模块
    use rooch_framework::gas_coin::RGas;     // 导入 Rooch 框架中的燃气代币模块，并引入 RGas 类型
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::agent_state::{Self, AgentState};  // 导入 nuwa_framework 中的代理状态模块，并引入 AgentState 类型

    const BALANCE_DESCRIPTION: vector<u8> = b"This is your balances";  // 定义常量：余额描述

    //TODO remove                            // 注释：待办事项：移除此结构体
    #[data_struct]
    struct BalanceState has copy, drop, store {  // 定义余额状态结构体（旧版），具有 copy、drop、store 能力
        coin_symbol: String,                 // 代币符号
        coin_type: String,                   // 代币类型
        decimals: u8,                        // 小数位数
        balance: u256,                       // 余额（256 位无符号整数）
    }

    #[data_struct]
    struct BalanceStateV2 has copy, drop, store {  // 定义余额状态结构体 V2，具有 copy、drop、store 能力
        coin_symbol: String,                 // 代币符号
        coin_type: String,                   // 代币类型
        balance: DecimalValue,               // 余额（十进制值）
    }
    
    public fun get_state(agent: &Object<Agent>): AgentState {  // 定义公开函数：获取代理的余额状态
        //TODO support dynamic get coin info and balance  // 注释：待办事项：支持动态获取代币信息和余额
        let balance_states = vector::empty();  // 初始化空的余额状态向量
        let coin_type = type_info::type_name<RGas>();  // 获取 RGas 的类型名称
        let coin_symbol = coin::symbol_by_type<RGas>();  // 获取 RGas 的符号
        let decimals = coin::decimals_by_type<RGas>();  // 获取 RGas 的小数位数
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        let balance = account_coin_store::balance<RGas>(agent_address);  // 获取代理的 RGas 余额
        let balance_state = BalanceStateV2 {  // 创建 BalanceStateV2 实例
            coin_symbol,                     // 代币符号
            coin_type,                       // 代币类型
            balance: decimal_value::new(balance, decimals),  // 余额（转换为十进制值）
        };
        vector::push_back(&mut balance_states, balance_state);  // 将余额状态添加到向量
        let state_json = string::utf8(json::to_json(&balance_states));  // 将余额状态转换为 JSON 字符串

        agent_state::new_agent_state(string::utf8(BALANCE_DESCRIPTION), state_json)  // 创建并返回代理状态
    }

    #[test]
    fun test_balance_state() {               // 定义测试函数：测试余额状态
        let balance_state = BalanceStateV2 {  // 创建 BalanceStateV2 实例
            coin_symbol: string::utf8(b"RGas"),  // 代币符号：RGas
            coin_type: string::utf8(b"0x3::gas_coin::RGas"),  // 代币类型
            balance: decimal_value::new(110000000, 8),  // 余额：1.1 RGas（假设 8 位小数）
        };
        let state_json = string::utf8(json::to_json(&balance_state));  // 将余额状态转换为 JSON 字符串
        std::debug::print(&state_json);      // 打印 JSON 字符串（调试用）
    }
}