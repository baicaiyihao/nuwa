module nuwa_framework::ai_service {
    use std::string;                          // 导入标准库中的字符串模块
    use std::vector;                          // 导入标准库中的向量模块
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use std::signer;                          // 导入标准库中的签名者模块
    use std::u256;                            // 导入标准库中的 256 位无符号整数模块
    use moveos_std::object::ObjectID;         // 导入 MoveOS 标准库中的对象 ID 类型
    use moveos_std::account;                  // 导入 MoveOS 标准库中的账户模块
    use verity::oracles;                      // 导入 verity 库中的 oracles 模块
    use verity::registry;                     // 导入 verity 库中的 registry 模块
    use rooch_framework::account_coin_store;  // 导入 Rooch 框架中的账户代币存储模块
    use rooch_framework::gas_coin::RGas;      // 导入 Rooch 框架中的燃气代币模块，并引入 RGas 类型

    use nuwa_framework::ai_request::{Self, ChatRequest};  // 导入 nuwa_framework 中的 AI 请求模块，并引入 ChatRequest 类型
    use nuwa_framework::agent_input::{AgentInputInfo, AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入 AgentInputInfo 和 AgentInputInfoV2 类型

    friend nuwa_framework::ai_callback;       // 声明 ai_callback 模块为友元模块
    friend nuwa_framework::agent;             // 声明 agent 模块为友元模块
    friend nuwa_framework::agent_runner;      // 声明 agent_runner 模块为友元模块

    const ORACLE_ADDRESS: address = @0x694cbe655b126e9e6a997e86aaab39e538abf30a8c78669ce23a98740b47b65d;  // 定义常量：预言机地址
    const NOTIFY_CALLBACK: vector<u8> = b"ai_callback::process_response_v2";  // 定义常量：通知回调函数路径
    /// Default gas allocation for notification callbacks 0.6 RGas  // 注释：通知回调的默认燃气分配 0.6 RGas
    const DEFAULT_NOTIFICATION_GAS: u256 = 200000000;  // 定义常量：默认通知燃气值
    const DEFAULT_ORACLE_FEE: u256 = 3200000000;  // 定义常量：默认预言机费用

    const AI_ORACLE_HEADERS: vector<u8> = b"{}";  // 定义常量：AI 预言机请求头（空 JSON）
    const AI_ORACLE_METHOD: vector<u8> = b"POST";  // 定义常量：AI 预言机请求方法（POST）

    /// The path to the message content in the oracle response  // 注释：预言机响应中消息内容的路径
    /// We directly get the root, if we want to get the first choice we can use ".choices[].message.content"  // 注释：直接获取根路径，若需获取第一个选择可用 ".choices[].message.content"
    const AI_PICK: vector<u8> = b".";         // 定义常量：AI 响应提取路径（根路径）
    const AI_ORACLE_URL: vector<u8> = b"https://api.openai.com/v1/chat/completions";  // 定义常量：AI 预言机 URL
    const MAX_HISTORY_MESSAGES: u64 = 20;     // 定义常量：最大历史消息数
    const MAX_RESPONSE_LENGTH: u64 = 65536;   // 定义常量：最大响应长度

    const ErrorInvalidDepositAmount: u64 = 1;  // 定义错误码：无效存款金额
    const ErrorInsufficientBalance: u64 = 2;   // 定义错误码：余额不足

    struct PendingRequest has copy, drop, store {  // 定义待处理请求结构体，具有 copy、drop、store 能力
        request_id: ObjectID,                 // 请求 ID
        agent_obj_id: ObjectID,               // 代理对象 ID
    }

    struct PendingRequestV2 has copy, drop, store {  // 定义待处理请求 V2 结构体，具有 copy、drop、store 能力
        request_id: ObjectID,                 // 请求 ID
        agent_obj_id: ObjectID,               // 代理对象 ID
        agent_input_info: AgentInputInfo,     // 代理输入信息
    }

    struct PendingRequestV3 has copy, drop, store {  // 定义待处理请求 V3 结构体，具有 copy、drop、store 能力
        request_id: ObjectID,                 // 请求 ID
        agent_obj_id: ObjectID,               // 代理对象 ID
        agent_input_info: AgentInputInfoV2,   // 代理输入信息 V2
    }

    struct Requests has key {                 // 定义请求结构体，具有 key 能力
        pending: vector<PendingRequest>,      // 待处理请求列表
    }

    struct RequestsV2 has key {               // 定义请求 V2 结构体，具有 key 能力
        pending: vector<PendingRequestV2>,    // 待处理请求 V2 列表
    }

    struct RequestsV3 has key {               // 定义请求 V3 结构体，具有 key 能力
        pending: vector<PendingRequestV3>,    // 待处理请求 V3 列表
    }

    fun init() {                              // 定义函数：初始化模块
        let signer = moveos_std::signer::module_signer<Requests>();  // 获取模块签名者
        account::move_resource_to(&signer, Requests {  // 将 Requests 资源移动到模块账户
            pending: vector::empty()          // 初始化空的待处理请求列表
        });
        init_v2();                            // 调用初始化 V2 函数
    }

    entry fun init_v2() {                     // 定义入口函数：初始化 V2
        let signer = moveos_std::signer::module_signer<RequestsV2>();  // 获取模块签名者
        account::move_resource_to(&signer, RequestsV2 {  // 将 RequestsV2 资源移动到模块账户
            pending: vector::empty()          // 初始化空的待处理请求 V2 列表
        });
    }

    entry fun init_v3() {                     // 定义入口函数：初始化 V3
        let signer = moveos_std::signer::module_signer<RequestsV3>();  // 获取模块签名者
        account::move_resource_to(&signer, RequestsV3 {  // 将 RequestsV3 资源移动到模块账户
            pending: vector::empty()          // 初始化空的待处理请求 V3 列表
        });
    }

    public(friend) fun request_ai(            // 定义友元函数：请求 AI 服务
        from: &signer,                        // 调用者签名者
        agent_obj_id: ObjectID,               // 代理对象 ID
        agent_input_info: AgentInputInfoV2,   // 代理输入信息 V2
        request: ChatRequest,                 // 聊天请求
    ) {
        let url = string::utf8(AI_ORACLE_URL);  // 将 AI 预言机 URL 转换为字符串
        let method = string::utf8(AI_ORACLE_METHOD);  // 将请求方法转换为字符串
        let headers = string::utf8(AI_ORACLE_HEADERS);  // 将请求头转换为字符串
        
        // Use ai_request to build the chat context  // 注释：使用 ai_request 构建聊天上下文
        let body = string::utf8(ai_request::to_json(&request));  // 将聊天请求转换为 JSON 格式的字符串
        
        let pick = string::utf8(AI_PICK);     // 将提取路径转换为字符串
        let http_request = oracles::build_request(url, method, headers, body);  // 构建 HTTP 请求
        
        let option_min_amount = registry::estimated_cost(ORACLE_ADDRESS, url, string::length(&body), MAX_RESPONSE_LENGTH);  // 估算预言机费用
        
        let estimated_fee: u256 = if (option::is_some(&option_min_amount)) {  // 如果估算费用存在
            option::destroy_some(option_min_amount)  // 获取估算费用
        } else {
            DEFAULT_ORACLE_FEE                // 否则使用默认预言机费用
        };
        let oracle_fee = u256::max(estimated_fee, DEFAULT_ORACLE_FEE);  // 取估算费用与默认费用的最大值
        let oracle_fee = oracle_fee + DEFAULT_NOTIFICATION_GAS;  // 加上默认通知燃气费用
        
        let from_addr = signer::address_of(from);  // 获取调用者地址
        let oracle_balance = oracles::get_user_balance(from_addr);  // 获取用户的预言机余额
        if (oracle_balance < oracle_fee) {    // 如果余额不足
            let pay_mee = oracle_fee - oracle_balance;  // 计算需要支付的差额
            let gas_balance = account_coin_store::balance<RGas>(from_addr);  // 获取用户的 RGas 余额
            assert!(gas_balance >= pay_mee, ErrorInsufficientBalance);  // 断言：确保 RGas 余额足够，否则抛出余额不足错误
            oracles::deposit_to_escrow(from, pay_mee);  // 存入差额到预言机托管账户
        };

        oracles::update_notification_gas_allocation(from, @nuwa_framework, string::utf8(NOTIFY_CALLBACK), DEFAULT_NOTIFICATION_GAS);  // 更新通知燃气分配
        
        let request_id = oracles::new_request(  // 创建新的预言机请求并获取请求 ID
            http_request,                     // HTTP 请求
            pick,                             // 提取路径
            ORACLE_ADDRESS,                   // 预言机地址
            oracles::with_notify(@nuwa_framework, string::utf8(NOTIFY_CALLBACK))  // 设置通知回调
        );

        // Store request information with agent ID  // 注释：存储请求信息与代理 ID
        let requests = account::borrow_mut_resource<RequestsV3>(@nuwa_framework);  // 借用可变的 RequestsV3 资源
        vector::push_back(&mut requests.pending, PendingRequestV3 {  // 将新请求添加到待处理列表
            request_id,                       // 请求 ID
            agent_obj_id,                     // 代理对象 ID
            agent_input_info,                 // 代理输入信息
        });
    }

    public fun get_pending_requests(): vector<PendingRequest> {  // 定义公开函数：获取待处理请求列表
        let requests = account::borrow_resource<Requests>(@nuwa_framework);  // 借用 Requests 资源
        *&requests.pending                    // 返回待处理请求列表的副本
    }

    public fun unpack_pending_request(request: PendingRequest): (ObjectID, ObjectID) {  // 定义公开函数：解包待处理请求
        (request.request_id, request.agent_obj_id)  // 返回请求 ID 和代理对象 ID
    }

    public fun get_pending_requests_v2(): vector<PendingRequestV2> {  // 定义公开函数：获取待处理请求 V2 列表
        let requests = account::borrow_resource<RequestsV2>(@nuwa_framework);  // 借用 RequestsV2 资源
        *&requests.pending                    // 返回待处理请求 V2 列表的副本
    }

    public fun unpack_pending_request_v2(request: PendingRequestV2): (ObjectID, ObjectID, AgentInputInfo) {  // 定义公开函数：解包待处理请求 V2
        (request.request_id, request.agent_obj_id, request.agent_input_info)  // 返回请求 ID、代理对象 ID 和代理输入信息
    }

    public fun get_pending_requests_v3(): vector<PendingRequestV3> {  // 定义公开函数：获取待处理请求 V3 列表
        let requests = account::borrow_resource<RequestsV3>(@nuwa_framework);  // 借用 RequestsV3 资源
        *&requests.pending                    // 返回待处理请求 V3 列表的副本
    }

    public fun unpack_pending_request_v3(request: PendingRequestV3): (ObjectID, ObjectID, AgentInputInfoV2) {  // 定义公开函数：解包待处理请求 V3
        (request.request_id, request.agent_obj_id, request.agent_input_info)  // 返回请求 ID、代理对象 ID 和代理输入信息 V2
    }

    public fun take_pending_request_by_id(request_id: ObjectID): Option<PendingRequestV3> {  // 定义公开函数：通过请求 ID 取出待处理请求
        //TODO use a key-value store to optimize the lookup  // 注释：待办事项：使用键值存储优化查找
        let requests = account::borrow_mut_resource<RequestsV3>(@nuwa_framework);  // 借用可变的 RequestsV3 资源
        let i = 0;                            // 初始化索引
        let len = vector::length(&requests.pending);  // 获取待处理请求列表长度
        while (i < len) {                     // 遍历待处理请求
            if (vector::borrow(&requests.pending, i).request_id == request_id) {  // 如果找到匹配的请求 ID
                return option::some(vector::remove(&mut requests.pending, i))  // 移除并返回该请求
            };
            i = i + 1;                        // 索引递增
        };
        option::none()                        // 未找到匹配，返回 None
    }

    public(friend) fun remove_request(request_id: ObjectID) {  // 定义友元函数：移除请求
        let requests = account::borrow_mut_resource<RequestsV3>(@nuwa_framework);  // 借用可变的 RequestsV3 资源
        let i = 0;                            // 初始化索引
        let len = vector::length(&requests.pending);  // 获取待处理请求列表长度
        while (i < len) {                     // 遍历待处理请求
            if (vector::borrow(&requests.pending, i).request_id == request_id) {  // 如果找到匹配的请求 ID
                vector::remove(&mut requests.pending, i);  // 移除该请求
                break;                        // 退出循环
            };
            i = i + 1;                        // 索引递增
        };
    }

    public fun get_user_oracle_fee_balance(user_addr: address): u256 {  // 定义公开函数：获取用户预言机费用余额
        oracles::get_user_balance(user_addr)  // 返回用户的预言机余额
    }

    public entry fun withdraw_user_oracle_fee(caller: &signer, amount: u256) {  // 定义入口函数：提取用户预言机费用
        oracles::withdraw_from_escrow(caller, amount)  // 从托管账户提取指定金额
    }

    public entry fun withdraw_all_user_oracle_fee(caller: &signer) {  // 定义入口函数：提取所有用户预言机费用
        let balance = oracles::get_user_balance(signer::address_of(caller));  // 获取调用者的预言机余额
        oracles::withdraw_from_escrow(caller, balance)  // 提取全部余额
    }

    public entry fun deposit_user_oracle_fee(caller: &signer, amount: u256) {  // 定义入口函数：存入用户预言机费用
        // Check user's RGas balance          // 注释：检查用户的 RGas 余额
        let caller_addr = signer::address_of(caller);  // 获取调用者地址
        let gas_balance = account_coin_store::balance<RGas>(caller_addr);  // 获取 RGas 余额
        assert!(gas_balance >= amount, ErrorInsufficientBalance);  // 断言：确保余额足够，否则抛出余额不足错误
        
        oracles::deposit_to_escrow(caller, amount)  // 存入指定金额到预言机托管账户
    }

    #[test]
    fun test_oracle_fee_operations() {       // 定义测试函数：测试预言机费用操作
        oracles::init_for_test();             // 为测试初始化预言机模块

        // Initialize test accounts          // 注释：初始化测试账户
        let alice = account::create_signer_for_testing(@0x77);  // 创建测试签名者 Alice
        let alice_addr = signer::address_of(&alice);  // 获取 Alice 的地址

        // Setup test account with initial RGas  // 注释：为测试账户设置初始 RGas
        let fee_amount: u256 = 1000000000;    // 定义费用金额：10 RGas
        rooch_framework::gas_coin::faucet_entry(&alice, fee_amount);  // 为 Alice 发放 10 RGas

        // Test Case 1: Check initial balance  // 注释：测试用例 1：检查初始余额
        {
            let initial_balance = get_user_oracle_fee_balance(alice_addr);  // 获取 Alice 的初始预言机余额
            assert!(initial_balance == 0, 1);  // 断言：初始余额为 0
        };

        // Test Case 2: Deposit and check balance  // 注释：测试用例 2：存入并检查余额
        {
            deposit_user_oracle_fee(&alice, fee_amount);  // Alice 存入 10 RGas
            let balance = get_user_oracle_fee_balance(alice_addr);  // 获取余额
            assert!(balance == fee_amount, 2);  // 断言：余额等于存入金额
        };

        // Test Case 3: Partial withdrawal  // 注释：测试用例 3：部分提取
        {
            let withdraw_amount = fee_amount / 2;  // 计算提取金额：5 RGas
            withdraw_user_oracle_fee(&alice, withdraw_amount);  // 提取 5 RGas
            let balance = get_user_oracle_fee_balance(alice_addr);  // 获取余额
            assert!(balance == withdraw_amount, 3);  // 断言：余额等于剩余金额（5 RGas）
        };

        // Test Case 4: Withdraw all remaining balance  // 注释：测试用例 4：提取所有剩余余额
        {
            withdraw_all_user_oracle_fee(&alice);  // 提取所有剩余余额
            let balance = get_user_oracle_fee_balance(alice_addr);  // 获取余额
            assert!(balance == 0, 4);         // 断言：余额为 0
        };
    }
}