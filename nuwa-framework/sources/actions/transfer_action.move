module nuwa_framework::transfer_action {
    use std::vector;                         // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option;                         // 导入标准库中的选项模块
    use moveos_std::object::{Object};        // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::type_info;               // 导入 MoveOS 标准库中的类型信息模块
    use moveos_std::result::{ok, err_str, Result};  // 导入 MoveOS 标准库中的结果模块，并引入相关类型和函数
    use rooch_framework::transfer;           // 导入 Rooch 框架中的转账模块
    use rooch_framework::gas_coin::RGas;     // 导入 Rooch 框架中的燃气代币模块，并引入 RGas 类型
    use rooch_framework::account_coin_store;  // 导入 Rooch 框架中的账户代币存储模块
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::action::{Self, ActionDescription, ActionGroup};  // 导入 nuwa_framework 中的动作模块，并引入相关类型
    use nuwa_framework::agent_input::{AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入 AgentInputInfoV2 类型

    // Action names                         // 注释：动作名称
    const ACTION_NAME_TRANSFER: vector<u8> = b"transfer::coin";  // 定义常量：转账动作名称
    // Action examples                      // 注释：动作示例
    const TRANSFER_ACTION_EXAMPLE: vector<u8> = b"{\"to\":\"rooch1a47ny79da3tthtnclcdny4xtadhaxcmqlnpfthf3hqvztkphcqssqd8edv\",\"amount\":\"100\",\"coin_type\":\"0x0000000000000000000000000000000000000000000000000000000000000003::gas_coin::RGas\",\"memo\":\"Payment for services\"}";  // 定义常量：转账动作示例

    #[data_struct]
    /// Arguments for the transfer coin action  // 注释：转账动作的参数
    struct TransferActionArgs has copy, drop {  // 定义转账动作参数结构体，具有 copy 和 drop 能力
        to: address,          // 接收者地址（字符串格式）
        amount: String,         // 转账金额（字符串）
        coin_type: String,    // 转账代币类型（完全限定类型名称）
        memo: String,         // 可选的转账备注，留空表示不需要
    }

    /// Register all transfer-related actions  // 注释：注册所有转账相关动作
    public fun register_actions() {          // 定义公开函数：注册动作
        // 当前为空实现
    }

    entry fun register_actions_entry() {     // 定义入口函数：注册动作入口
        register_actions();                  // 调用注册动作函数
    }

    public fun get_action_group(): ActionGroup {  // 定义公开函数：获取动作组
        action::new_action_group(            // 创建并返回新的动作组
            string::utf8(b"transfer"),       // 命名空间：transfer
            string::utf8(b"Actions related to coin transfers, including sending and managing coins."),  // 描述
            get_action_descriptions()        // 动作描述列表
        )   
    }

    public fun get_action_descriptions(): vector<ActionDescription> {  // 定义公开函数：获取动作描述
        let descriptions = vector::empty();  // 初始化空的动作描述向量
        // Register transfer coin action     // 注释：注册转账代币动作
        let transfer_args = vector[          // 创建转账动作参数列表
            action::new_action_argument(     // 创建参数：接收者地址
                string::utf8(b"to"),         // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"Recipient address"),  // 描述
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 创建参数：金额
                string::utf8(b"amount"),     // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"Amount to transfer (as a string)"),  // 描述
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 创建参数：代币类型
                string::utf8(b"coin_type"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"Coin type to transfer (e.g. '0x0000000000000000000000000000000000000000000000000000000000000003::gas_coin::RGas')"),  // 描述
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 创建参数：备注
                string::utf8(b"memo"),       // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"Optional memo for the transfer, leave empty if not needed"),  // 描述
                true,                        // 是否必需
            ),
        ];
        vector::push_back(&mut descriptions, action::new_action_description(  // 添加转账动作描述
            string::utf8(ACTION_NAME_TRANSFER),  // 动作名称
            string::utf8(b"Transfer coin_type coins to an address"),  // 描述
            transfer_args,                   // 参数列表
            string::utf8(TRANSFER_ACTION_EXAMPLE),  // 参数示例
            string::utf8(b"Use this action to transfer coin_type coins from your account to another address"),  // 使用提示
            string::utf8(b"Transfers will be executed immediately and are irreversible"),  // 约束
        ));
        descriptions                         // 返回动作描述列表
    }
    
    public fun execute(_agent: &mut Object<Agent>, _action_name: String, _args_json: String) {  // 定义公开函数：执行动作（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    /// Execute a transfer action           // 注释：执行转账动作
    public fun execute_v3(agent: &mut Object<Agent>, _agent_input: &AgentInputInfoV2, action_name: String, args_json: String): Result<bool, String> {  // 定义公开函数：执行动作 V3
        if (action_name == string::utf8(ACTION_NAME_TRANSFER)) {  // 如果动作名称是转账
            let args_opt = json::from_json_option<TransferActionArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (option::is_none(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for transfer action")  // 返回错误：无效参数
            };

            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            execute_transfer(agent, args.to, args.amount, args.coin_type)  // 执行转账
        } else {
            err_str(b"Unsupported action")      // 返回错误：不支持的动作
        }
    }

    /// Execute the transfer operation with dynamic coin type support  // 注释：执行转账操作，支持动态代币类型
    fun execute_transfer(agent: &mut Object<Agent>, to: address, amount_str: String, coin_type_str: String): Result<bool, String> {  // 定义函数：执行转账
        let signer = agent::create_agent_signer(agent);  // 创建代理签名者
        
        // Handle different coin types based on the string value  // 注释：根据字符串值处理不同的代币类型
        if (coin_type_str == type_info::type_name<RGas>()) {  // 如果代币类型是 RGas
            let decimal = 8;                 // 设置 RGas 的小数位数为 8
            let amount_opt = moveos_std::string_utils::parse_decimal_option(&amount_str, decimal);  // 解析金额
            if (option::is_none(&amount_opt)) {  // 如果金额解析失败
                return err_str(b"Invalid amount for transfer")  // 返回错误：无效金额
            };
            let amount = option::destroy_some(amount_opt);  // 提取解析出的金额
            let agent_address = agent::get_agent_address(agent);  // 获取代理地址
            let balance = account_coin_store::balance<RGas>(agent_address);  // 获取代理余额
            if (balance < amount) {          // 如果余额不足
                return err_str(b"Insufficient balance for transfer")  // 返回错误：余额不足
            };
            transfer::transfer_coin<RGas>(&signer, to, amount);  // 执行 RGas 转账
            ok(true)                         // 返回成功结果
        } else {
            err_str(b"Unsupported coin type")   // 返回错误：不支持的代币类型
        }
    }

    #[test]
    fun test_transfer_action_examples() {    // 定义测试函数：测试转账动作示例
        // Test transfer action example       // 注释：测试转账动作示例
        let transfer_args = json::from_json<TransferActionArgs>(TRANSFER_ACTION_EXAMPLE);  // 从 JSON 示例解析参数
        assert!(transfer_args.to == @0xed7d3278adec56bbae78fe1b3254cbeb6fd36360fcc295dd31b81825d837c021, 0);  // 断言：接收者地址正确
        assert!(transfer_args.amount == string::utf8(b"100"), 1);  // 断言：金额正确
        assert!(transfer_args.coin_type == string::utf8(b"0x0000000000000000000000000000000000000000000000000000000000000003::gas_coin::RGas"), 2);  // 断言：代币类型正确
        assert!(transfer_args.memo == string::utf8(b"Payment for services"), 3);  // 断言：备注正确
        std::debug::print(&type_info::type_name<RGas>());  // 打印 RGas 类型名称（调试用）
        assert!(transfer_args.coin_type == type_info::type_name<RGas>(), 4);  // 断言：代币类型与 RGas 匹配
    }
}