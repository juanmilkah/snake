const std = @import("std");
const rl = @import("raylib");

// window constants
const windowHeight: i32 = 700;
const windowWidth: i32 = 1000;
const windowBorderColor = rl.Color.white;
const windowBackgroundColor = rl.Color.black;
const borderXOffset = 20;
const borderYOffset = 20;
const gameBoxHeight = windowHeight - borderYOffset;
const gameBoxWidth = windowWidth - borderXOffset * 2;
const minX = borderXOffset + snakeSegmentDimensions.width;
const minY = borderYOffset + snakeSegmentDimensions.height;
const maxX = gameBoxWidth - snakeSegmentDimensions.width;
const maxY = gameBoxHeight - snakeSegmentDimensions.height;
const helpMenuColor = rl.Color.green;

// fruit constants
const fruitDimensions = .{
    .width = 20,
    .height = 20,
};
const fruitColor = rl.Color.orange;

// snake
const initiaSnakeDirection = Direction.Right;
const intialSnakeLength = 3;
const initialSnakePosition: Position = .{ .x = 200, .y = 200 };
const snakeSegmentDimensions = .{
    .width = 20,
    .height = 20,
};
const snakeHeadColor = rl.Color.red;
const snakeSegmentColor = rl.Color.violet;
const snakeMoveSize: u32 = 20;

// objects
const Fruit = struct {
    position: Position,
    rec: rl.Rectangle,

    fn init(pos: Position) Fruit {
        return .{ .position = pos, .rec = rl.Rectangle{
            .x = @floatFromInt(pos.x),
            .y = @floatFromInt(pos.y),
            .width = @floatFromInt(fruitDimensions.width),
            .height = @floatFromInt(fruitDimensions.height),
        } };
    }

    fn updateRec(self: *Fruit) void {
        self.*.rec = .{
            .x = @floatFromInt(self.*.position.x),
            .y = @floatFromInt(self.*.position.y),
            .width = @floatFromInt(fruitDimensions.width),
            .height = @floatFromInt(fruitDimensions.height),
        };
    }
};

const Snake = struct {
    head: Position,
    direction: Direction,
    body: std.ArrayList(Position),

    fn getHeadRec(self: *const Snake) rl.Rectangle {
        return .{
            .x = @floatFromInt(self.*.head.x),
            .y = @floatFromInt(self.*.head.y),
            .width = @floatFromInt(snakeSegmentDimensions.width),
            .height = @floatFromInt(snakeSegmentDimensions.height),
        };
    }
};

const Direction = enum { Up, Down, Right, Left };

const Position = struct { x: i32, y: i32 };

const GameState = enum { Paused, Pending, Running, Over };

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
        .Up => snake.head.y -= snakeMoveSize,
        .Down => snake.head.y += snakeMoveSize,
        .Left => snake.head.x -= snakeMoveSize,
        .Right => snake.head.x += snakeMoveSize,
    }
}

// check snake head collision with the window border
fn hasCollidedBorder(snake: *const Snake) bool {
    if (snake.head.x < minX or
        snake.head.y < minY or
        snake.head.x > maxX or
        snake.head.y > maxY)
    {
        return true;
    }
    return false;
}

// check snake head collision with its body segments
fn hasCollidedSelf(snake: *const Snake) bool {
    const headRec = snake.*.getHeadRec();
    for (snake.body.items) |segment| {
        const segmentRec = rl.Rectangle{
            .x = @floatFromInt(segment.x),
            .y = @floatFromInt(segment.y),
            .width = @floatFromInt(snakeSegmentDimensions.width),
            .height = @floatFromInt(snakeSegmentDimensions.height),
        };
        if (rl.checkCollisionRecs(headRec, segmentRec)) return true;
    }

    return false;
}

fn hasEatenFruit(snake: *const Snake, fruit: *const Fruit) bool {
    return rl.checkCollisionRecs(snake.*.getHeadRec(), fruit.*.rec);
}

// generate new fruit position within the game box
fn randomizeFruitPosition(rand: std.Random) Position {
    const x = std.Random.intRangeAtMost(rand, i32, 0, (maxX - minX) / snakeMoveSize);
    const y = std.Random.intRangeAtMost(rand, i32, 0, (maxY - minY) / snakeMoveSize);

    return Position{
        .x = minX + x * snakeMoveSize,
        .y = minY + y * snakeMoveSize,
    };
}

// check if the new fruit position is within the snake's body
fn isPositionInSnake(fruitPos: *const Position, snake: *const Snake) bool {
    const headRec = snake.*.getHeadRec();

    // fruit in head ?
    const fruitRec = rl.Rectangle{
        .x = @floatFromInt(fruitPos.*.x),
        .y = @floatFromInt(fruitPos.*.y),
        .height = @floatFromInt(fruitDimensions.height),
        .width = @floatFromInt(fruitDimensions.width),
    };

    if (rl.checkCollisionRecs(fruitRec, headRec)) {
        return true;
    }

    // fruit in segments ?
    for (snake.*.body.items) |segment| {
        const segmentRec = rl.Rectangle{
            .x = @floatFromInt(segment.x),
            .y = @floatFromInt(segment.y),
            .width = @floatFromInt(snakeSegmentDimensions.width),
            .height = @floatFromInt(snakeSegmentDimensions.height),
        };

        if (rl.checkCollisionRecs(segmentRec, fruitRec)) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    rl.initWindow(windowWidth, windowHeight, "Snake Raylib");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // random number generator
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const allocator = std.heap.page_allocator;

    // Game variables
    var counter: u32 = 0;
    var frameCounter: u32 = 0;
    var gameState = GameState.Pending;

    var snakeBody = std.ArrayList(Position).init(allocator);
    defer snakeBody.deinit();

    var snake: Snake = .{
        .head = initialSnakePosition,
        .direction = Direction.Right,
        .body = snakeBody,
    };

    // assuming intial direction is right
    for (1..intialSnakeLength) |i| {
        const segmentPos = Position{
            .x = snake.head.x - snakeSegmentDimensions.width * std.math.cast(i32, i).?,
            .y = snake.head.y,
        };

        try snake.body.append(segmentPos);
    }

    var initialFruitPosition = randomizeFruitPosition(rand);
    while (isPositionInSnake(&initialFruitPosition, &snake)) {
        initialFruitPosition = randomizeFruitPosition(rand);
    }
    var fruit = Fruit.init(initialFruitPosition);

    var scoreTextBuf: [32]u8 = undefined;

    // event loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        if (rl.isKeyPressed(rl.KeyboardKey.q) or rl.isKeyPressed(rl.KeyboardKey.escape)) {
            break;
        }

        rl.clearBackground(windowBackgroundColor);

        // Draw title
        rl.drawText(
            "Snake",
            windowWidth / 2 - @divFloor(rl.measureText(
                "Snake",
                20,
            ), 2),
            0,
            20,
            rl.Color.gold,
        );

        // draw borders
        rl.drawRectangleLines(
            borderXOffset,
            borderYOffset,
            gameBoxWidth,
            gameBoxHeight,
            windowBorderColor,
        );

        switch (gameState) {
            .Paused => {
                rl.drawText(
                    "Press Space to continue!",
                    windowWidth / 2 - @divFloor(rl.measureText(
                        "Press Space to continue!",
                        20,
                    ), 2),
                    windowHeight / 2 + 10,
                    20,
                    helpMenuColor,
                );

                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    gameState = .Running;
                }

                if (rl.isKeyPressed(rl.KeyboardKey.q)) {
                    gameState = .Over;
                }

                // Draw score
                const scoreText = try std.fmt.bufPrintZ(&scoreTextBuf, "Score: {}", .{counter});
                rl.drawText(scoreText, 20, 0, 20, rl.Color.green);

                // Draw fruit
                rl.drawRectangleRec(fruit.rec, fruitColor);

                // Draw snake body
                for (snake.body.items) |segment| {
                    rl.drawRectangle(
                        segment.x,
                        segment.y,
                        snakeSegmentDimensions.width,
                        snakeSegmentDimensions.height,
                        snakeSegmentColor,
                    );
                }

                // Draw snake head
                rl.drawRectangleRec(snake.getHeadRec(), snakeHeadColor);
            },
            // Not yet started
            .Pending => {
                rl.clearBackground(windowBackgroundColor);
                rl.drawText(
                    "Snake 2D Game",
                    windowWidth / 2 - @divFloor(rl.measureText(
                        "Snake 2D Game",
                        20,
                    ), 2),
                    windowHeight / 2 - 50,
                    20,
                    helpMenuColor,
                );
                rl.drawText(
                    "Use the arrows for control",
                    windowWidth / 2 - @divFloor(rl.measureText(
                        "Use the arrows for control",
                        20,
                    ), 2),
                    windowHeight / 2 - 20,
                    20,
                    helpMenuColor,
                );
                rl.drawText(
                    "Press Space to start!",
                    windowWidth / 2 - @divFloor(rl.measureText("Press Space to start!", 20), 2),
                    windowHeight / 2 + 10,
                    20,
                    helpMenuColor,
                );

                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    gameState = .Paused;
                }
            },
            .Running => {
                if (rl.isKeyPressed(rl.KeyboardKey.space)) {
                    gameState = .Paused;
                }

                frameCounter += 1;

                if (frameCounter >= 8) { // Update game logic every 8 frames for slower movement
                    frameCounter = 0;

                    // Store the old head position before moving, for tail growth
                    const oldHeadPosition = snake.head;

                    updateSnakePosition(&snake);

                    if (hasCollidedBorder(&snake) or hasCollidedSelf(&snake)) {
                        gameState = .Over;
                    }

                    if (hasEatenFruit(&snake, &fruit)) {
                        counter += 1;
                        try snake.body.insert(0, oldHeadPosition);
                        fruit.position = randomizeFruitPosition(rand);
                        while (isPositionInSnake(&fruit.position, &snake)) {
                            fruit.position = randomizeFruitPosition(rand);
                        }
                        fruit.updateRec();
                    }
                }

                updateSnakeDirection(&snake);

                // Draw score
                const scoreText = try std.fmt.bufPrintZ(&scoreTextBuf, "Score: {}", .{counter});
                rl.drawText(scoreText, 20, 0, 20, rl.Color.green);

                // Draw fruit
                rl.drawRectangleRec(fruit.rec, fruitColor);

                // Draw snake body
                for (snake.body.items) |segment| {
                    rl.drawRectangle(
                        segment.x,
                        segment.y,
                        snakeSegmentDimensions.width,
                        snakeSegmentDimensions.height,
                        snakeSegmentColor,
                    );
                }

                // Draw snake head
                rl.drawRectangleRec(snake.getHeadRec(), snakeHeadColor);

                // help
                rl.drawText(
                    "Press Space to pause game or q to quit!",
                    borderXOffset,
                    maxY + borderYOffset * 2,
                    20,
                    rl.Color.green,
                );
            },
            .Over => {
                // Draw score
                const scoreText = try std.fmt.bufPrintZ(&scoreTextBuf, "Score: {}", .{counter});
                rl.drawText(scoreText, 20, 0, 20, rl.Color.green);

                rl.drawText(
                    "Game Over!",
                    windowWidth / 2 - @divFloor(rl.measureText("Game Over!", 30), 2),
                    windowHeight / 2 - 30,
                    30,
                    rl.Color.gold,
                );
                rl.drawText(
                    "Press R to Restart",
                    windowWidth / 2 - @divFloor(rl.measureText("Press R to Restart", 20), 2),
                    windowHeight / 2 + 10,
                    20,
                    rl.Color.gray,
                );

                // Draw fruit
                rl.drawRectangleRec(fruit.rec, fruitColor);

                // Draw snake body
                for (snake.body.items) |segment| {
                    rl.drawRectangle(
                        segment.x,
                        segment.y,
                        snakeSegmentDimensions.width,
                        snakeSegmentDimensions.height,
                        snakeSegmentColor,
                    );
                }

                // Draw snake head
                rl.drawRectangleRec(snake.getHeadRec(), snakeHeadColor);

                if (rl.isKeyPressed(rl.KeyboardKey.r)) {
                    // reset game state
                    snake.head = initialSnakePosition;
                    snake.body.clearAndFree(); // Clear and free memory
                    snake.direction = Direction.Right;

                    // assuming intial direction is right
                    for (1..intialSnakeLength) |i| {
                        const segmentPos = Position{
                            .x = snake.head.x - snakeSegmentDimensions.width * std.math.cast(
                                i32,
                                i,
                            ).?,
                            .y = snake.head.y,
                        };

                        try snake.body.append(segmentPos);
                    }

                    // Randomize fruit and ensure it's not on the snake
                    fruit.position = randomizeFruitPosition(rand);
                    while (isPositionInSnake(&fruit.position, &snake)) {
                        fruit.position = randomizeFruitPosition(rand);
                    }
                    fruit.updateRec();
                    counter = 0;
                    gameState = .Running;
                }
            },
        }
    }
}
