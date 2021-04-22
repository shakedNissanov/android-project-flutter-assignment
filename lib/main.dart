import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';
import 'snapping_sheet.dart';

String? email;
Set<WordPair> saved = <WordPair>{};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthRepository.instance(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(
          primaryColor: Colors.red,
        ),
        home: (email == null) ? RandomWords() : PreviewPage(),
      ),
    );
  }
}

void addUserDocument(String email, Set<WordPair> saved) {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  _firestore.collection("favorites").doc(email);
  List<String> l =  saved.map((WordPair wordPairItem) => wordPairItem.asPascalCase.toString()).toList();
  _firestore.collection("favorites").doc(email).set({"data": l});
}

Future<void> getSavedFromDB() async {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  await _firestore.collection("favorites").doc(email!).get().then((value) {
      List.from(value.data()!['data']).forEach((element) {
        final beforeNonLeadingCapitalLetter = RegExp(r"(?=(?!^)[A-Z])");
        List<String> splitPascalCase(String input) =>
            input.split(beforeNonLeadingCapitalLetter);
        List<String> split = splitPascalCase(element.toString());
        WordPair pair = new WordPair(split[0].toLowerCase(), split[1].toLowerCase());
        saved.add(pair);
      });
  });
}

class LoginScreen extends StatefulWidget {
  Function callback;
  LoginScreen(this.callback);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final errorLoginSnackbar = SnackBar(content: Text('There was an error logging into the app'));
  final passwordsMatchSnackbar = SnackBar(content: Text('Passwords must match'));
  final emailField = TextEditingController();
  final passwordField = TextEditingController();
  final verifyPasswordField = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    emailField.dispose();
    passwordField.dispose();
    verifyPasswordField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login")
      ),
      body: Padding(padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text("Welcome to Startup Names Generator, please log in below", style: TextStyle(fontSize: 18),),
          TextField(
            controller: emailField,
            decoration: InputDecoration(
            border: UnderlineInputBorder(),
            hintText: 'Email'
            ),
          ),
          TextField(
            controller: passwordField,
            decoration: InputDecoration(
            border: UnderlineInputBorder(),
            hintText: 'Password'
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Consumer<AuthRepository>(
              builder: ((context, auth, _) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: (auth.status != Status.Authenticating) ? Colors.red : Colors.black, // background
                    onPrimary: Colors.white, // foreground
                  ),
                  onPressed: () {
                    if(auth.status == Status.Authenticating) {
                      return null;
                    }
                    else {
                      var result = auth.signIn(
                          emailField.text, passwordField.text);
                      result.then((value) {
                        if (value == false) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              errorLoginSnackbar);
                        }
                        else {
                          setState(() {
                            email = emailField.text;
                            getSavedFromDB().then((value) {
                              addUserDocument(emailField.text, saved);
                              this.widget.callback();
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => PreviewPage()),
                              );
                            });
                          });
                        }
                      });
                    }
                  },
                  child: Text("Log in"),
              )),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Consumer<AuthRepository>(
              builder: ((context, auth, _) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.red, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: 200,
                        color: Colors.white,
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: const Text('Please confirm your password below:'),
                            ),
                            TextField(
                              controller: verifyPasswordField,
                              decoration: InputDecoration(
                                  border: UnderlineInputBorder(),
                                  hintText: 'Password'
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: (auth.status != Status.Authenticating) ? Colors.red : Colors.black, // background
                                  onPrimary: Colors.white, // foreground
                                ),
                                onPressed: () {
                                  if(passwordField.text == verifyPasswordField.text) {
                                    auth.signUp(emailField.text, passwordField.text).then((value) {
                                      email = emailField.text;
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                    });
                                  }
                                  else {
                                    ScaffoldMessenger.of(context).showSnackBar(passwordsMatchSnackbar);
                                  }
                                },
                                child: Text("Confirm"),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Text("New user? Click to sign up"),
              )),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User? _user;
  Status _status = Status.Uninitialized;

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  User? get user => _user;

  bool get isAuthenticated => status == Status.Authenticated;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  late LoginScreen loginScreen;

  @override
  void initState() {
    super.initState();
    loginScreen = LoginScreen(this.callback);
  }

  void callback() {
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
          Consumer<AuthRepository>(
            builder: (context, auth, _) {
              if(auth.status == Status.Unauthenticated || auth.status == Status.Uninitialized) {
                return IconButton(icon: Icon(Icons.login), onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen(callback)),
                  );
                });
              }
              else {
                return IconButton(icon: Icon(Icons.exit_to_app), onPressed: () {
                  auth.signOut();
                  setState(() {
                    saved = <WordPair>{};
                    email = null;
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => RandomWords()),
                  );
                });
              }
            }
          )
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final tiles = saved.map(
                (WordPair pair) {
              return ListTile(
                title: Text(
                  pair.asPascalCase,
                  style: _biggerFont,
                ),
                trailing: IconButton(icon: Icon(Icons.delete), onPressed: () {
                  setState(() {
                    saved.remove(pair);
                  });
                  if(email != null) {
                    addUserDocument(email!, saved);
                  }
                  Navigator.pop(context);
                  _pushSaved(); // Not the cleanest of solutions, but it does the job :)
                },),
              );
            },
          );
          final divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return Divider();
          }
          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = saved.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),
      onTap: () {
        setState(() {
          if (alreadySaved) {
            saved.remove(pair);
            if(email != null) {
              addUserDocument(email!, saved);
            }
          } else {
            saved.add(pair);
            if(email != null) {
              addUserDocument(email!, saved);
            }
          }
        });
      },
    );
  }
}