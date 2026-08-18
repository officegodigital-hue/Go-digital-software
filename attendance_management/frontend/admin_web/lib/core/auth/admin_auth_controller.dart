import 'package:flutter/foundation.dart';

import 'admin_auth_repository.dart';
import 'admin_auth_session.dart';


class AdminAuthController extends ChangeNotifier {


  AdminAuthController({
    AdminAuthRepository? repository,
  }) : _repository =
          repository ?? AdminAuthRepository();



  final AdminAuthRepository _repository;



  bool _isInitializing = true;
  bool _isSigningIn = false;
  bool _isAuthenticated = false;
  bool _disposed = false;



  String? _errorMessage;

  String? _token;



  Map<String,dynamic> _user =
      <String,dynamic>{};





  bool get isInitializing =>
      _isInitializing;


  bool get isSigningIn =>
      _isSigningIn;


  bool get isAuthenticated =>
      _isAuthenticated;


  String? get errorMessage =>
      _errorMessage;



  // FIX TOKEN ERROR
  String get token =>
      _token ?? '';





  Map<String,dynamic> get user {

    return Map<String,dynamic>.unmodifiable(
      _user
    );

  }






  String get userName {

    return _readUserValue(
      [
        'name',
        'full_name',
        'fullName'
      ],
      fallback:'Admin'
    );

  }




  String get userEmail {

    return _readUserValue(
      [
        'email'
      ]
    );

  }





  String get userRole {

    return _readUserValue(
      [
        'role'
      ],
      fallback:'Admin'
    );

  }





  String get companyName {

    return _readUserValue(
      [
        'company_name',
        'companyName'
      ],
      fallback:'GoDigital'
    );

  }





  String get branchName {

    return _readUserValue(
      [
        'branch_name',
        'branchName'
      ],
      fallback:'Guduvanchery'
    );

  }





  // FIX PROFILE IMAGE ERROR

  String get profileImageUrl {

    return _readUserValue(
      [
        'profile_image_url',
        'profileImageUrl',
        'image',
        'avatar'
      ]
    );

  }








  Future<void> initialize() async {


    _isInitializing=true;

    _errorMessage=null;


    _notifySafely();



    try {


      _token =
          await AdminAuthSession.getAccessToken();



      final bool hasSession =
          await _repository.hasActiveSession();




      if(!hasSession){


        _isAuthenticated=false;

        _user={};

        _token=null;


        return;

      }






      final Map<String,dynamic> savedUser =
          await _repository.getSavedUser();




      _user =
          Map<String,dynamic>.from(
            savedUser
          );



      _isAuthenticated=true;




      try{


        final Map<String,dynamic> currentUser =
            await _repository.getCurrentUser();



        if(currentUser.isNotEmpty){

          _user =
              Map<String,dynamic>.from(
                currentUser
              );

        }



      }
      on AdminAuthException catch(error){



        if(error.statusCode==401 ||
           error.statusCode==403){


          await AdminAuthSession.clear();


          _token=null;

          _isAuthenticated=false;

          _user={};


        }


      }



    }

    catch(error){


      _errorMessage =
          _friendlyError(
            error,
            fallback:
            'Unable to restore admin session'
          );


      _isAuthenticated=false;

      _user={};

      _token=null;


    }



    finally{


      _isInitializing=false;


      _notifySafely();


    }



  }









  Future<bool> signIn({

    required String email,

    required String password,

  }) async {



    if(_isSigningIn){

      return false;

    }



    _isSigningIn=true;

    _errorMessage=null;


    _notifySafely();



    try {



      final AdminLoginResult result =
          await _repository.login(

            email:
            email.trim().toLowerCase(),

            password:
            password,

          );




      _token =
          await AdminAuthSession.getAccessToken();





      _user =
          Map<String,dynamic>.from(
            result.user
          );




      _isAuthenticated=true;



      return true;



    }


    catch(error){


      _isAuthenticated=false;



      _errorMessage =
          _friendlyError(
            error,
            fallback:
            'Unable to sign in'
          );


      return false;


    }



    finally{


      _isSigningIn=false;


      _notifySafely();


    }


  }









  Future<void> signOut() async {



    _errorMessage=null;



    try{


      await _repository.logout();


    }


    finally{


      _token=null;


      _isAuthenticated=false;


      _user={};


      _notifySafely();


    }


  }









  void clearError({

    bool notify=true

  }){


    _errorMessage=null;


    if(notify){

      _notifySafely();

    }


  }









  String _readUserValue(

      List<String> keys, {

      String fallback='',

      }){


    for(final key in keys){


      final value =
          _user[key];


      if(value!=null){


        final String data =
            value.toString().trim();



        if(data.isNotEmpty){

          return data;

        }


      }


    }



    return fallback;


  }









  String _friendlyError(

      Object error, {

      required String fallback

      }){


    if(error is AdminAuthException){


      return error.message.isEmpty
          ? fallback
          : error.message;


    }



    return error
        .toString()
        .replaceFirst(
          'Exception:',
          ''
        )
        .trim();


  }









  void _notifySafely(){


    if(!_disposed){

      notifyListeners();

    }


  }






  @override
  void dispose(){


    _disposed=true;


    super.dispose();


  }



}