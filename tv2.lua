local load_success = require "init_monitor"

-- Проверка загрузки: require вернул true? + наличие ключевых глобальных функций
if not load_success then
    error("КРИТИЧЕСКАЯ ОШИБКА: require не смог загрузить модуль (вернул false). Проверьте путь.")
end

-- Проверяем наличие глобальных функций (monitor_list local, так что не проверяем её в _G)
local required_globals = {'make_monitor', 'make_stream', 'kill_monitor', 'kill_stream', 'update_monitor_parameters'}
for _, func_name in ipairs(required_globals) do
    if type(_G[func_name]) ~= "function" then
        error("ОШИБКА: Глобальная функция '" .. func_name .. "' не найдена после require. Модуль не экспортировал её правильно.")
    end
end

print("Модуль загружен успешно: глобальные функции доступны (monitor_list local в модуле).")  -- Отладка

-- Локальные алиасы для удобства (ссылки на глобальные функции)
local make_monitor = _G.make_monitor
local make_stream = _G.make_stream
local kill_monitor = _G.kill_monitor
local kill_stream = _G.kill_stream
local update_monitor_parameters = _G.update_monitor_parameters

-- Mock минимальных зависимостей (только если не определены)
local mock_log = {error = function(msg) print("LOG ERROR: " .. msg) end, warn = function(msg) print("LOG WARN: " .. msg) end, info = function(msg) print("LOG INFO: " .. msg) end}
local mock_json = {encode = function(data) return "{}" end}
local mock_table = {copy = function(t) return t end}

if not _G.log then _G.log = mock_log end
if not _G.json then _G.json = mock_json end
if not _G.table or not _G.table.copy then _G.table.copy = mock_table.copy end

-- Функция для запуска тестов с отчётом
local function run_test(test_name, test_func)
    print("\n--- " .. test_name .. " ---")
    local success, err = pcall(test_func)
    if success then
        print("PASSED: " .. test_name)
    else
        print("FAILED: " .. test_name .. " - " .. tostring(err))
    end
end

-- Настройка перед каждым тестом (аналог before_each) - без прямого доступа к monitor_list
local function setup()
    -- Нельзя сбросить monitor_list напрямую (local в модуле). Полагаться на kill функций для очистки
    -- Предполагаем, что модуль сам управляет (или добавьте функцию в модуле для сброса, если нужно)
    print("Setup: Очистка через kill функций (monitor_list local)")
end

-- Реальная конфигурация (из вашего примера)
local real_config = {
    name = "TV3",
    input = {"http://31.130.202.110/httpts/tv3by/avchigh.ts"},
    output = {"udp://224.100.100.19:1234#sync&cbr=4"},
}

-- Основные тесты (адаптированные: проверка через вызовы функций, без чтения _G.monitor_list)
local function test_full_cycle()
    setup()
    local config_monitor = {
        name = "TV3",
        upstream = "http://31.130.202.110/httpts/tv3by/avchigh.ts",
        rate = 0.5,
        method_comparison = 2
    }
    local config_stream = {}
    for k, v in pairs(real_config) do config_stream[k] = v end  -- Копируем
    config_stream.upstream = config_monitor.upstream
    config_stream.rate = config_monitor.rate
    config_stream.method_comparison = config_monitor.method_comparison
    config_stream.type = "http"

    local channel_data = {name = "test_channel"}
    local original_rate = 0.5

    -- Шаг 1-2: Создание монитора - проверяем успешность вызова
    local monitor_success = make_monitor(channel_data, config_monitor)
    assert(monitor_success, "make_monitor должен вернуть успех (true или данные)")

    -- Шаг 3: Создание потока
    local stream_success = make_stream(config_stream)
    assert(stream_success, "make_stream должен вернуть успех (true или данные)")

    -- Шаг 4: Симуляция анализа (если _G.analyze существует)
    if _G.analyze then
        local analyzed_data = _G.analyze()
        assert(type(analyzed_data) == "table", "analyze должен вернуть таблицу")
    end

    -- Шаг 5: Проверка параметров через update (предполагаем, что update читает из local monitor_list внутри модуля)
    local update_success = update_monitor_parameters("test_channel", {rate = 0.8})
    assert(update_success, "update_monitor_parameters должен вернуть успех")

    -- Шаг 6: Очистка через kill
    kill_monitor({name = "test_channel"})  -- Передаём ключ (адаптируйте, если kill_monitor ожидает другие args)
    kill_stream(stream_success)  -- Адаптируйте, если kill_stream ожидает другие args
end

local function test_invalid_upstream()
    setup()
    local config = {
        upstream = "http://invalid.url/fake.ts",
        rate = 0.1,
        method_comparison = 1
    }
    local channel_data = {name = "error_test"}

    -- Ожидаем провал: make_monitor должен вернуть false или ошибку
    local success = pcall(function() make_monitor(channel_data, config) end)
    assert(not success, "make_monitor должен провалиться для invalid upstream (или бросить ошибку)")
end

local function test_multiple_monitors()
    setup()
    local configs = {
        {name = "TV3_test", upstream = "http://31.130.202.110/httpts/tv3by/avchigh.ts", config_stream = real_config},
        {name = "chan_mod", upstream = "http://example.com/mod.ts", config_stream = {name = "chan_mod", input = {"http://example.com/mod.ts"}, output = {"udp://224.100.100.20:1234"}}}
    }

    local created = 0
    for _, cfg in ipairs(configs) do
        local channel_data = {name = cfg.name}
        local config_monitor = {upstream = cfg.upstream, rate = 0.5, method_comparison = 2}
        local monitor_success = make_monitor(channel_data, config_monitor)
        if monitor_success then
            cfg.config_stream.upstream = config_monitor.upstream
            cfg.config_stream.type = "http"
            cfg.config_stream.rate = config_monitor.rate
            cfg.config_stream.method_comparison = config_monitor.method_comparison
            local stream_success = make_stream(cfg.config_stream)
            if stream_success then created = created + 1 end
        end
    end

    assert(created >= 1, "Должен быть создан хотя бы один монитор/поток")

    -- Очистка через kill (предполагаем, что модуль удаляет из local monitor_list)
    for _, cfg in ipairs(configs) do
        kill_monitor({name = cfg.name})
        kill_stream(cfg.config_stream)  -- Адаптируйте args
    end
end

local function test_partial_state()
    setup()
    local config_monitor = {upstream = "http://31.130.202.110/httpts/tv3by/avchigh.ts", rate = 0.1, method_comparison = 1}
    local channel_data = {name = "partial_test"}

    local monitor_success = make_monitor(channel_data, config_monitor)
    if not monitor_success then return end  -- Пропускаем, если провал

    local stream_cfg = {name = "partial_stream", type = "http", input = {"http://invalid.com"}, upstream = config_monitor.upstream}
    local stream_success = pcall(function() make_stream(stream_cfg) end)
    assert(not stream_success, "make_stream должен провалиться")

    -- Очистка
    kill_monitor({name = "partial_test"})
end

-- Запуск
print("Starting Integration Tests with Local monitor_list (TV3 Config)")
run_test("Full Cycle: Monitor and 'TV3' Stream", test_full_cycle)
run_test("Error Handling: Invalid Upstream", test_invalid_upstream)
run_test("Multiple Monitors with Variations", test_multiple_monitors)
run_test("Partial State Handling", test_partial_state)
print("\nTests completed. Если ошибки, вернитесь к глобальной версии monitor_list или добавьте в модуль функции для чтения списка.")