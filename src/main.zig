const std = @import("std");
const zap = @import("zap"); // ZAP 0.9.0

pub fn main() !void {
    // Инициализируем аллокатор
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Ввод никнейма
    try stdout.print("Введите ваш никнейм: ");
    const nickLine = try std.io.readLineAlloc(allocator, stdin, 1024);
    const nick = std.mem.trimSpace(nickLine);

    // Выбор режима: подключиться или ожидать соединения
    try stdout.print("Подключиться к другому клиенту? (y/n): ");
    const modeLine = try std.io.readLineAlloc(allocator, stdin, 1024);
    const modeChoice = std.mem.trimSpace(modeLine);

    if (std.mem.eql(u8, modeChoice, "y")) {
        // Режим клиента: ввод ip:port и попытка подключения
        try stdout.print("Введите ip:port: ");
        const addrLine = try std.io.readLineAlloc(allocator, stdin, 1024);
        const addr = std.mem.trimSpace(addrLine);

        // Создаем клиентское подключение через ZAP (ZAP 0.9.0)
        var client = try zap.Client.connect(allocator, addr);
        // Рукопожатие: отправка локального никнейма и получение никнейма собеседника
        try client.sendMessage(nick);
        const peerNick = try client.receiveMessage();
        try stdout.print("Подключено к клиенту: {s}\n", .{peerNick});

        // Запуск цикла переписки
        try chatLoop(allocator, client, nick);
    } else {
        // Режим сервера: слушаем порт и обрабатываем входящие соединения
        const port = "12345";
        var server = try zap.Server.listen(allocator, "0.0.0.0:" ++ port);
        try stdout.print("Ожидание подключений на порту {s}...\n", .{port});

        while (true) {
            const connection = try server.accept();
            // Для каждого нового подключения запускаем отдельный поток/задачу.
            _ = std.Thread.spawn(handleConnection, connection, nick) catch {
                try stdout.print("Не удалось запустить обработчик подключения\n", .{});
                continue;
            };
        }
    }
}

/// Цикл обмена сообщениями для клиентского подключения.
/// Пользователь отправляет сообщение, затем ждет ответ.
fn chatLoop(allocator: *std.mem.Allocator, client: zap.Client, localNick: []const u8) !void {
    var stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    while (true) {
        try stdout.print("{s}> ", .{localNick});
        const msgLine = try std.io.readLineAlloc(allocator, stdin, 1024);
        const msg = std.mem.trimSpace(msgLine);
        if (std.mem.eql(u8, msg, "exit")) break;
        try client.sendMessage(msg);
        const reply = try client.receiveMessage();
        try stdout.print("Друг: {s}\n", .{reply});
    }
}

/// Обработчик входящего соединения (для серверного режима).
/// Выполняется для каждого нового клиента: обмен никнеймами и вывод полученных сообщений.
fn handleConnection(connection: zap.Connection, localNick: []const u8) !void {
    var stdout = std.io.getStdOut().writer();

    // Рукопожатие: обмен никнеймами
    try connection.sendMessage(localNick);
    const peerNick = try connection.receiveMessage();
    try stdout.print("Клиент {s} подключился\n", .{peerNick});

    while (true) {
        const msg = try connection.receiveMessage();
        try stdout.print("{s}: {s}\n", .{peerNick, msg});
    }
}

