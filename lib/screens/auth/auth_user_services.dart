import 'dart:convert';

import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/model/login_model.dart';
import 'package:booking_system_flutter/model/user_data_model.dart';
import 'package:booking_system_flutter/network/network_utils.dart';
import 'package:booking_system_flutter/network/rest_apis.dart';
import 'package:booking_system_flutter/utils/constant.dart';
import 'package:booking_system_flutter/utils/model_keys.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'package:nb_utils/nb_utils.dart';

Future<(UserData, LoginResponse?)> loginCurrentUsers(BuildContext context, {required Map<String, dynamic> req, bool isSocialLogin = false, bool isOtpLogin = false}) async {
  try {
    appStore.setLoading(true);

    String? uid = req['uid'];

    final userValue = await loginUser(req, isSocialLogin: isSocialLogin);

    log("***************** Normal Login Succeeds*****************");

    if (isOtpLogin) {
      userValue.userData!.uid = uid;
      return (UserData(), userValue);
    }

    final firebaseUid = await firebaseLogin(context, userData: userValue.userData!, isSocialLogin: isSocialLogin);

    userValue.userData!.uid = firebaseUid;
    userValue.userData!.password = req['password'];

    return (userValue.userData!, userValue);
  } catch (e) {
    log("<<<<<<$e>>>>>>");
    throw e.toString();
  } finally {
    appStore.setLoading(false);
  }
}

Future<String> firebaseLogin(BuildContext context, {required UserData userData, bool isSocialLogin = false}) async {
  try {
    final firebaseEmail = userData.email.validate();
    final firebaseUid = await authService.signInWithEmailPassword(email: firebaseEmail, uid: userData.uid.validate(), isSocialLogin: isSocialLogin);

    log("***************** User Already Registered in Firebase*****************");

    if (!isSocialLogin && await userService.isUserExistWithUid(firebaseUid)) {
      return firebaseUid;
    } else {
      userData.uid = firebaseUid;
      log("user : ${userData.uid}");
      return await authService.setRegisterData(userData: userData).catchError((ee) {
        throw "Cannot Register";
      });
    }
  } catch (e) {
    if (e.toString() == USER_NOT_FOUND) {
      log("***************** ($e) User Not Found, Again registering the current user *****************");

      return await registerUserInFirebase(context, user: userData);
    } else {
      throw e.toString();
    }
  }
}

Future<String> registerUserInFirebase(BuildContext context, {required UserData user}) async {
  try {
    log("*************************************************** Login user is registering again.  ***************************************************");
    return authService.signUpWithEmailPassword(context, userData: user);
  } catch (e) {
    throw e.toString();
  }
}

Future<void> updatePlayerId() async {
  MultipartRequest multiPartRequest = await getMultiPartRequest('update-profile');
  Map<String, dynamic> req = {
    UserKeys.id: appStore.userId,
    UserKeys.playerId: getStringAsync(PLAYERID),
  };

  multiPartRequest.fields.addAll(await getMultipartFields(val: req));

  multiPartRequest.headers.addAll(buildHeaderTokens());

  log("MultiPart Request : ${jsonEncode(multiPartRequest.fields)} ${multiPartRequest.files.map((e) => e.field + ": " + e.filename.validate())}");

  await sendMultiPartRequest(multiPartRequest, onSuccess: (temp) async {
    appStore.setLoading(false);

    if ((temp as String).isJson()) {
      userService.updatePlayerIdInFirebase(email: appStore.userEmail.validate(), playerId: getStringAsync(PLAYERID));
    }
  }, onError: (error) {
    toast(error.toString(), print: true);
    appStore.setLoading(false);
  }).catchError((e) {
    appStore.setLoading(false);
    toast(e.toString());
  });
}
