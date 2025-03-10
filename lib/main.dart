import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Matching Game',
      home: GameScreen(),
    );
  }
}

class GameProvider extends ChangeNotifier {
  List<CardModel> _cards = [];
  CardModel? _firstCard;
  bool _isBusy = false;
  Timer? _timer;
  int _timeElapsed = 0;
  int _score = 0;

  GameProvider() {
    _initializeGame();
  }

  List<CardModel> get cards => _cards;
  int get timeElapsed => _timeElapsed;
  int get score => _score;

  void _initializeGame() {
    _cards = [];
    // Create pairs of cards for a 4x4 grid (8 pairs).
    List<int> cardValues = List.generate(8, (index) => index);
    // Duplicate each value to form pairs.
    cardValues = [...cardValues, ...cardValues];
    cardValues.shuffle();

    for (int i = 0; i < cardValues.length; i++) {
      _cards.add(CardModel(id: i, value: cardValues[i]));
    }
    _firstCard = null;
    _isBusy = false;
    _timeElapsed = 0;
    _score = 0;
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _timeElapsed++;
      notifyListeners();
    });
  }

  void flipCard(CardModel card) {
    if (_isBusy || card.isFaceUp || card.isMatched) return;
    card.isFaceUp = true;
    notifyListeners();

    if (_firstCard == null) {
      _firstCard = card;
    } else {
      _isBusy = true;
      // Check if the two selected cards match.
      if (_firstCard!.value == card.value) {
        // Match found.
        _firstCard!.isMatched = true;
        card.isMatched = true;
        _score += 10;
        _resetSelection();
        _checkWinCondition();
      } else {
        // No match: deduct score and flip cards back after a short delay.
        _score = _score > 0 ? _score - 2 : 0;
        Future.delayed(Duration(seconds: 1), () {
          _firstCard!.isFaceUp = false;
          card.isFaceUp = false;
          _resetSelection();
          notifyListeners();
        });
      }
    }
  }

  void _resetSelection() {
    _firstCard = null;
    _isBusy = false;
    notifyListeners();
  }

  void _checkWinCondition() {
    bool allMatched = _cards.every((card) => card.isMatched);
    if (allMatched) {
      _timer?.cancel();
      notifyListeners();
    }
  }

  void restartGame() {
    _timer?.cancel();
    _initializeGame();
  }
}

class CardModel {
  final int id;
  final int value;
  bool isFaceUp;
  bool isMatched;

  CardModel({
    required this.id,
    required this.value,
    this.isFaceUp = false,
    this.isMatched = false,
  });
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    // Check win condition: if all cards are matched and dialog hasn't been shown.
    if (gameProvider.cards.isNotEmpty &&
        gameProvider.cards.every((card) => card.isMatched) &&
        !_dialogShown) {
      _dialogShown = true;
      Future.delayed(Duration.zero, () => _showWinDialog());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Card Matching Game'),
      ),
      body: Column(
        children: [
          // Timer and Score Display
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Time: ${gameProvider.timeElapsed}s',
                    style: TextStyle(fontSize: 20)),
                Text('Score: ${gameProvider.score}',
                    style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
          // Card Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4x4 grid
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: gameProvider.cards.length,
              itemBuilder: (context, index) {
                final card = gameProvider.cards[index];
                return GestureDetector(
                  onTap: () => gameProvider.flipCard(card),
                  child: CardWidget(card: card),
                );
              },
            ),
          ),
          // Restart Button
          ElevatedButton(
            onPressed: () {
              setState(() {
                _dialogShown = false;
              });
              gameProvider.restartGame();
            },
            child: Text('Restart Game'),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces the user to tap OK.
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Yay!! You won the game 😊"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WinAnimationWidget(),
              SizedBox(height: 16),
              Text("Congratulations on matching all the cards!"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset the dialog flag so it can be shown again on restart.
                setState(() {
                  _dialogShown = false;
                });
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}

class CardWidget extends StatelessWidget {
  final CardModel card;
  const CardWidget({Key? key, required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        final rotate = Tween(begin: pi, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotate,
          child: child,
          builder: (context, child) {
            final isUnder = (ValueKey(card.isFaceUp) != child!.key);
            var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
            tilt *= isUnder ? -1.0 : 1.0;
            return Transform(
              transform: Matrix4.rotationY(rotate.value)..setEntry(3, 0, tilt),
              child: child,
            );
          },
        );
      },
      child: card.isFaceUp || card.isMatched
          ? Container(
              key: ValueKey(true),
              color: Colors.blue,
              child: Center(
                child: Text(
                  '${card.value}',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : Container(
              key: ValueKey(false),
              color: Colors.grey,
            ),
    );
  }
}

class WinAnimationWidget extends StatefulWidget {
  @override
  _WinAnimationWidgetState createState() => _WinAnimationWidgetState();
}

class _WinAnimationWidgetState extends State<WinAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    // Animation that rotates the trophy icon continuously.
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(
        Icons.emoji_events,
        size: 50,
        color: Colors.amber,
      ),
    );
  }
}
