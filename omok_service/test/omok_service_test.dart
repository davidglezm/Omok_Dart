import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// STABLE VERSION 1.0 ---
// BUGS
// 1. When winning it does not recognize the winner -> Tryng to access 'move' key not present 
// 2. 
void main() async
{
  //final defaultUrl = "https://cssrvlab01.utep.edu/Classes/cs3360Cheon/scarrillo14/OmokService/src/info/index.php";
  // Setup own Omok Web Server - David Gonzalez
  final defaultUrl = "https://aboutdavidgonzalez.com/omok/info/";
  final consoleUI = ConsoleUI();
  final webClient = WebClient();
  final responseParser = ResponseParser();
  final omokController = OmokController(consoleUI, webClient, responseParser, defaultUrl);

  try
  {
    await omokController.playGame();
  }
  catch(e)
  {
    print("An error occurred: $e");
  }
}

class OmokController
{
  final ConsoleUI consoleUI;
  final WebClient webClient;
  final ResponseParser responseParser;
  final String defaultUrl;

  OmokController(this.consoleUI, this.webClient, this.responseParser, this.defaultUrl);
    
  Future<void> playGame() async
  {
    // --- Introduction ---
    consoleUI.showMessage('Welcome to Omok Game!');
    var url = consoleUI.promptServer(defaultUrl);
    consoleUI.showMessage('Obtaining server information...');

    // Show user availble strategies from omok web server
    final serverData = await webClient.getInfo(url);
    final strategies = responseParser.parseInfo(serverData);
    consoleUI.showMessage('Server Data: ${strategies.join(', ')}');

    // Store user selection
    var userSelection = consoleUI.promptStrategy();
    consoleUI.showMessage('You selected: $userSelection');
    consoleUI.showMessage('Creating new game...');

    // --- STARTING THE GAME --- David Gonzalez
    // Create new game on the omok web server with chosen strategy(userSelection variable)
    String gameResponse = await webClient.createNewGame(userSelection);
    // Store pid for created game
    String pid = responseParser.parsePid(gameResponse);
    //print(pid);
    // Initializing the board to hold state of current game. 
    Board game = Board();
    game.initialize();
    
    bool gameWon = false;

    // Game loop - David Gonzalez
    while (!gameWon) {
      // Prompt user for move
      var userMove = consoleUI.promptForMove();
      int x = userMove[0];
      int y = userMove[1];

      // Send move to server
      String serverResponse;
      try {
        serverResponse = await webClient.sendMove(pid.toString(), x, y);
      } catch (e) {
        print("An error occurred while sending move: $e");
        continue; // Go to the next iteration of the loop
      }

      // Process server response
      if (json.decode(serverResponse)['response'] == false) {
        consoleUI.showMessage("Invalid move: ${json.decode(serverResponse)['reason']}");
        continue;
      } else {
        // Update board with user move
        game.makeMove(x, y, 'O');

        // Extract server move
        var serverMove = json.decode(serverResponse)['move'];
        int serverX = serverMove['x'];
        int serverY = serverMove['y'];

        // Update board with server move
        game.makeMove(serverX, serverY, 'X');

        // Print updated board
        game.printBoard();

        // Check for win condition
        gameWon = responseParser.parseIsWin(serverResponse);
      }
    }

    consoleUI.showMessage("Game Over! ${gameWon ? 'Someone has won!' : 'It\'s a draw!'}");
  }

    // TESTING Board class hold status - WORKS!!! - David Gonzalez
    // game.printBoard();
    // game.makeMove(5, 2, 'W');
    // game.printBoard();
    // game.makeMove(12, 14, 'X');
    // game.printBoard();
    
    // Initial Board Setup => before Board Class implementation 
    // consoleUI.showMessage("   1 2 3 4 5 6 7 8 9 0 1 2 3 4 5");
    // consoleUI.showMessage("y  -----------------------------");
    // for(int i =0;i<9;i++){
    //   int curr = i + 1;
    //     consoleUI.showMessage(curr.toString() + "| . . . . . . . . . . . . . . .");
    // }
    // for(int i=-1;i<5;i++){
    //   int curr = i + 1;
    //     consoleUI.showMessage(curr.toString() + "| . . . . . . . . . . . . . . .");
    // }
}

class ConsoleUI
{
  void showMessage(String message)
  {
    print(message);
  }

  String promptServer(String defaultUrl)
  {
    stdout.write('Enter the server URL [default: $defaultUrl]: ');
    var url = stdin.readLineSync() ?? defaultUrl;
    return url;
  }

  String promptStrategy()
  {
    int? selection;
    do
    {
      stdout.write('Enter your selection, 1.Smart 2.Random: ');
      var line = stdin.readLineSync();
      selection = int.tryParse(line ?? '');
    }
    while (selection != 1 && selection != 2);

    return selection == 1 ? 'Smart' : 'Random';
  }

  // User input prompter and checker - David Gonzalez
 List<int> promptForMove() {
    while (true) {
      stdout.write('Enter your move between 0-14 as [x y]: ');
      var input = stdin.readLineSync();

      if (input != null && input.isNotEmpty) {
        var parts = input.split(' ');

        if (parts.length == 2) {
          var x = int.tryParse(parts[0]);
          var y = int.tryParse(parts[1]);

          if (x != null && y != null) {
            if (x >= 0 && x < 15 && y >= 0 && y < 15) {
              return [x, y];
            } else {
              print('Invalid index. Please enter x and y coordinates between 0 and 14.');
              continue;
            }
          }
        }
      }

      print('Invalid input. Please enter x and y coordinates separated by a space (e.g., "0 3").');
    }
  }
}

class WebClient
{
  // Method to get Omok info from server
  Future<String> getInfo(String url) async{
    final response = await http.get(Uri.parse(url));
    if(response.statusCode == 200)
    {
      return response.body;
    }
    else
    {
      throw("Failed to fetch data from the server. Status code: ${response.statusCode}");
    }
  }
  
  // Method to send a request and record the response - David Gonzalez
  Future<String> createNewGame(String strategy) async {
    var url = 'https://aboutdavidgonzalez.com/omok/new/?strategy=$strategy';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed to create new game. Status code: ${response.statusCode}");
    }
  }
  // Method to send a move to the server - David Gonzalez
  Future<String> sendMove(String pid, int x, int y) async {
    var moveUrl = 'https://aboutdavidgonzalez.com/omok/play/?pid=$pid&move=$x,$y';
    final response = await http.get(Uri.parse(moveUrl));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed to send move. Status code: ${response.statusCode}");
    }
  }
}

class ResponseParser
{
  List<String> parseInfo(String response)
  {
    final info = json.decode(response);
    final strategies = info['strategies'] as List<dynamic>;
    return strategies.map((strategy) => strategy.toString()).toList();
  }
  // Method to parse the server response and return the pid - David Gonzalez
  String parsePid(String response) {
    final info = json.decode(response);
    return info['pid'] as String;
  }
  // Method to parse the server response for isWin result - David Gonzalez
  bool parseIsWin(String response) {
    final info = json.decode(response);

    // Check for 'reason' key
    if (info.containsKey('reason') && info['reason'] is Map) {
      return info['reason']['isWin'] as bool;
    }
    // Check for 'ack_move' key
    else if (info.containsKey('ack_move') && info['ack_move'] is Map) {
      return info['ack_move']['isWin'] as bool;
    }
    // Check for 'move' key
    else if (info.containsKey('move') && info['move'] is Map) {
      return info['move']['isWin'] as bool;
    }

    // Throw an exception if none of the expected keys are found
    throw Exception("Invalid server response format. Unable to find 'isWin' information.");
  }
}

// Class to hold the Board status - David Gonzalez
class Board {
  static const int size = 15; // Size of the Omok board
  List<List<String>> _grid = List.generate(size, (i) => List.filled(size, '.'));

  void initialize() {
    // Initialize the board with empty spaces
    _grid = List.generate(size, (i) => List.filled(size, '.'));
  }

  void printBoard() {
    // Print the column headers
    print("    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4");
    print("y  ------------------------------");

    // Print each row of the board
    for (int i = 0; i <= 9; i++) {
      String row = "${i} | ";
      row += _grid[i].join(' ');
      print(row);
    }
    for (int i = 0; i <= 4; i++) {
      String row = "${i} | ";
      row += _grid[i + 10].join(' ');
      print(row);
    }
  }
  // Update the board with the move
  // Erro Handling logic is done by the server
  void makeMove(int row, int col, String symbol) {
    _grid[row][col] = symbol; 
  }
}