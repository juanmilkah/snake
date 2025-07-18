const std = @import("std");
const rl = @import("raylib");

// window constants
const windowHeight: i32 = 600;
const windowWidth: i32 = 800;
const windowBorderColor = rl.Color.white;
const windowBackgroundColor = rl.Color.black;
const borderOffset = 20;
const maxX = windowWidth - borderOffset - snakeSegmentDimensions.width;
const maxY = windowHeight - borderOffset - snakeSegmentDimensions.height;

// fruit constants
const fruitDimensions = .{
    .width = 20,
    .height = 20,
};
const fruitColor = rl.Color.orange;
const initialFruitPosition: Position = .{
    .x = 100,
    .y = 100,
};

// snake
const initialSnakePosition: Position = .{ .x = 200, .y = 200 };
const snakeSegmentDimensions = .{
    .width = 20,
    .height = 20,
};
const initialSnakeLength: u32 = 3;
const snakeHeadColor = rl.Color.red;
const snakeSegmentColor = rl.Color.violet;
const snakeSpeed: u32 = 3;

// objects
const Fruit = struct {
    position: Position,
};

const Snake = struct { head: Position, direction: Direction, body: std.ArrayList(Position) };

const Direction = enum { Up, Down, Right, Left };

const Position = struct { x: i32, y: i32 };

// handle gameplay key presses to control the snake
fn updateSnakeDirection(snake: *Snake) void {
    if (rl.isKeyPressed(rl.KeyboardKey.up) and snake.direction != Direction.Down) {
        snake.direction = Direction.Up;
    }
    if (rl.isKeyPressed(rl.KeyboardKey.down) and snake.direction != Direction.Up) {
        snake.direction = Direction.Down;
    }
    if (rl.isKeyPressed(rl.KeyboardKey.left) and snake.direction != Direction.Right) {
        snake.direction = Direction.Left;
    }
    if (rl.isKeyPressed(rl.KeyboardKey.right) and snake.direction != Direction.Left) {
        snake.direction = Direction.Right;
    }
}

fn updateSnakePosition(snake: *Snake) void {
    if (snake.*.body.items.len > 0) {
        const len = snake.*.body.items.len;
        var i: usize = len - 1;
        while (i > 0) : (i -= 1) {
            snake.*.body.items[i] = snake.*.body.items[i - 1];
        }
        snake.*.body.items[0] = snake.head;
    }

    switch (snake.direction) {
        .Up => snake.head.y -= snakeSpeed,
        .Down => snake.head.y += snakeSpeed,
        .Left => snake.head.x -= snakeSpeed,
        .Right => snake.head.x += snakeSpeed,
    }
}

// check snake head collision with the window border
fn hasCollidedBorder(snake: *const Snake) bool {
    if (snake.head.x < borderOffset or
        snake.head.y < borderOffset or
        snake.head.x > maxX or
        snake.head.y > maxY)
    {
        return true;
    }
    return false;
}

// check snake head collision with its body segments
fn hasCollidedSelf(snake: *const Snake) bool {
    for (snake.body.items) |segment| {
        if (snake.*.head.x == segment.x and snake.*.head.y == segment.y) {
            return true;
        }
    }
    return false;
}

fn hasEatenFruit(snake: *const Snake, fruit: *const Fruit) bool {
    return rl.checkCollisionRecs(rl.Rectangle{
        .x = @floatFromInt(snake.*.head.x),
        .y = @floatFromInt(snake.*.head.y),
        .width = @floatFromInt(snakeSegmentDimensions.width),
        .height = @floatFromInt(snakeSegmentDimensions.height),
    }, rl.Rectangle{
        .x = @floatFromInt(fruit.*.position.x),
        .y = @floatFromInt(fruit.*.position.y),
        .width = @floatFromInt(fruitDimensions.width),
        .height = @floatFromInt(fruitDimensions.height),
    });
}

// generate new fruit position within the game box
fn randomizeFruitPosition(rand: std.Random) Position {
    const maximumX = windowWidth - 2 * borderOffset - fruitDimensions.width;
    const maximumY = windowHeight - 2 * borderOffset - fruitDimensions.height;

    const x = std.Random.intRangeAtMost(rand, i32, borderOffset, maximumX);
    const y = std.Random.intRangeAtMost(rand, i32, borderOffset, maximumY);

    return Position{ .x = x, .y = y };
}

// The end of the snake to attach new segment;
fn getTailSegment(snake: *const Snake) Position {
    if (snake.*.body.items.len == 0) {
        switch (snake.*.direction) {
            .Up => return .{
                .x = snake.*.head.x,
                .y = snake.*.head.y + snakeSegmentDimensions.width,
            },
            .Down => return .{
                .x = snake.*.head.x,
                .y = snake.*.head.y - snakeSegmentDimensions.height,
            },
            .Left => return .{
                .x = snake.*.head.x + snakeSegmentDimensions.width,
                .y = snake.*.head.y,
            },
            .Right => return .{
                .x = snake.*.head.x - snakeSegmentDimensions.height,
                .y = snake.*.head.y,
            },
        }
    }

    const tail = snake.*.body.items[snake.*.body.items.len - 1];

    const beforeTail = if (snake.*.body.items.len >= 2)
        snake.*.body.items[snake.*.body.items.len - 2]
    else
        snake.head;

    const dx = tail.x - beforeTail.x;
    const dy = tail.y - beforeTail.y;

    if (dx > 0) {
        return .{ .x = tail.x - snakeSegmentDimensions.width, .y = tail.y };
    } else if (dx < 0) {
        return .{ .x = tail.x + snakeSegmentDimensions.width, .y = tail.y };
    } else if (dy > 0) {
        return .{ .x = tail.x, .y = tail.y - snakeSegmentDimensions.height };
    } else if (dy < 0) {
        return .{ .x = tail.x, .y = tail.y + snakeSegmentDimensions.height };
    } else {
        return switch (snake.*.direction) {
            .Up => return .{
                .x = snake.*.head.x,
                .y = snake.*.head.y + snakeSegmentDimensions.width,
            },
            .Down => return .{
                .x = snake.*.head.x,
                .y = snake.*.head.y - snakeSegmentDimensions.height,
            },
            .Left => return .{
                .x = snake.*.head.x + snakeSegmentDimensions.width,
                .y = snake.*.head.y,
            },
            .Right => return .{
                .x = snake.*.head.x - snakeSegmentDimensions.height,
                .y = snake.*.head.y,
            },
        };
    }
}

// check if the new fruit position is within the snake's body
fn isPositionInSnake(fruitPos: *const Position, snake: *const Snake) bool {
    // fruit in head ?
    if (fruitPos.*.x == snake.*.head.x and fruitPos.*.y == snake.*.head.y) {
        return true;
    }

    // fruit in sgements ?
    for (snake.*.body.items) |segment| {
        if (fruitPos.*.x == segment.x and fruitPos.y == segment.y) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    rl.initWindow(windowWidth, windowHeight, "Snake Raylib");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var gameOver = false;

    // random number generator
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const allocator = std.heap.page_allocator;
    var snakeBody = std.ArrayList(Position).init(allocator);
    defer snakeBody.deinit();

    var snake: Snake = .{
        .head = initialSnakePosition,
        .direction = Direction.Right,
        .body = snakeBody,
    };
    var fruit: Fruit = .{ .position = randomizeFruitPosition(rand) };
    var counter: u32 = 0;

    var scoreTextBuf: [32]u8 = undefined;

    // event loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        // allow quiting
        if (rl.isKeyPressed(rl.KeyboardKey.q)) break;

        // handle game over state
        while (gameOver) {
            // rl.clearBackground(windowBackgroundColor);
            rl.drawText(
                "Game Over!",
                windowWidth / 2 - 100,
                windowHeight / 2 - 30,
                30,
                rl.Color.gold,
            );
            rl.drawText(
                "Press R to Restart",
                windowWidth / 2 - 120,
                windowHeight / 2 + 10,
                20,
                rl.Color.gray,
            );

            const scoreText = try std.fmt.bufPrintZ(&scoreTextBuf, "Score: {}", .{counter});
            rl.drawText(
                scoreText,
                windowWidth / 2 - 100,
                windowHeight / 2 + 40,
                20,
                rl.Color.green,
            );
            rl.endDrawing();

            if (rl.isKeyPressed(rl.KeyboardKey.q) or rl.isKeyPressed(rl.KeyboardKey.escape)) return;

            if (rl.isKeyPressed(rl.KeyboardKey.r)) {
                // reset game state
                snake.head = initialSnakePosition;
                try snake.body.resize(0);
                snake.direction = Direction.Right;
                fruit.position = randomizeFruitPosition(rand);
                counter = 0;
                gameOver = false;
            }
        }

        updateSnakeDirection(&snake);
        updateSnakePosition(&snake);

        if (hasCollidedBorder(&snake) or hasCollidedSelf(&snake)) {
            gameOver = true;
        }

        if (hasEatenFruit(&snake, &fruit)) {
            counter += 1;
            const tailSegment = getTailSegment(&snake);
            try snake.body.append(tailSegment);

            fruit.position = randomizeFruitPosition(rand);

            while (isPositionInSnake(&fruit.position, &snake)) {
                fruit.position = randomizeFruitPosition(rand);
            }
        }

        rl.clearBackground(windowBackgroundColor);

        const scoreText = try std.fmt.bufPrintZ(&scoreTextBuf, "Score: {}", .{counter});
        rl.drawText(scoreText, 20, 0, 20, rl.Color.green);
        rl.drawText(
            "Snake",
            windowWidth / 2,
            0,
            20,
            rl.Color.gold,
        );
        rl.drawRectangleLines(
            20,
            20,
            windowWidth - 40,
            windowHeight - 20,
            windowBorderColor,
        );
        rl.drawRectangle(
            fruit.position.x,
            fruit.position.y,
            fruitDimensions.width,
            fruitDimensions.height,
            fruitColor,
        );
        rl.drawRectangle(
            snake.head.x,
            snake.head.y,
            snakeSegmentDimensions.width,
            snakeSegmentDimensions.height,
            snakeHeadColor,
        );

        for (snake.body.items) |segment| {
            rl.drawRectangle(
                segment.x,
                segment.y,
                snakeSegmentDimensions.width,
                snakeSegmentDimensions.height,
                snakeSegmentColor,
            );
        }
    }
}
