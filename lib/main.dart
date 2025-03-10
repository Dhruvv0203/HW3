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
      // A victory message can be added here.
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

class GameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
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
              gameProvider.restartGame();
            },
            child: Text('Restart Game'),
          ),
          SizedBox(height: 16),
        ],
      ),
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
            // Create a 3D flip effect.
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
