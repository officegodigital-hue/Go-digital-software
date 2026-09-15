// lib/screens/SettingsPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/services/api_config.dart';
import 'package:godigital_portal/layouts/admin_layout.dart';

const List<String> _avatarColorOptions = [
  '#4F46E5','#0EA5E9','#16A34A','#D97706',
  '#DC2626','#7C3AED','#0891B2','#334155',
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static String get _baseUrl => ApiConfig.baseUrl;
  late TextEditingController _firstNameController,_middleNameController,
      _lastNameController,_usernameController,_emailController;
  String _staffId='',_role='',_avatarColorHex=_avatarColorOptions.first;
  String? _profilePhotoDataUrl;
  bool _photoChanged=false,_loadingProfile=true,_saving=false;

  static const primary=Color(0xFF0757D5);
  static const dark=Color(0xFF063B98);
  static const text=Color(0xFF14213D);
  static const muted=Color(0xFF718096);
  static const border=Color(0xFFE4EAF3);
  static const bg=Color(0xFFF5F8FC);

  @override void initState(){
    super.initState();
    _firstNameController=TextEditingController();
    _middleNameController=TextEditingController();
    _lastNameController=TextEditingController();
    _usernameController=TextEditingController();
    _emailController=TextEditingController();
    _loadProfile();
  }
  @override void dispose(){
    _firstNameController.dispose();_middleNameController.dispose();
    _lastNameController.dispose();_usernameController.dispose();
    _emailController.dispose();super.dispose();
  }

  Future<void> _loadProfile() async {
    final a=context.read<AuthService>(); final id=a.userId;
    setState(()=>_loadingProfile=true);
    try{
      final r=await http.get(Uri.parse('$_baseUrl/employees/$id'),
        headers:{'Authorization':'Bearer ${a.token}'});
      if(r.statusCode==200){
        final b=jsonDecode(r.body);
        final d=Map<String,dynamic>.from(b['data']??{});
        _firstNameController.text=d['first_name']??'';
        _middleNameController.text=d['middle_name']??'';
        _lastNameController.text=d['last_name']??'';
        _usernameController.text=d['username']??'';
        _emailController.text=d['email']??'';
        _staffId=d['staff_id']??''; _role=d['role']??'';
        _avatarColorHex=(d['avatar_color']??'').toString().isNotEmpty
          ? d['avatar_color'] : _avatarColorOptions.first;
        _profilePhotoDataUrl=(d['profile_photo']??'').toString().isNotEmpty
          ? d['profile_photo'] : null;
      }
    }catch(_){
      final u=a.user;
      _firstNameController.text=(u?['firstName']??'').toString();
      _lastNameController.text=(u?['lastName']??'').toString();
      _usernameController.text=(u?['username']??'').toString();
      _emailController.text=(u?['email']??'').toString();
      _staffId=(u?['staffId']??'').toString();
      _role=(u?['role']??'').toString();
    }
    if(mounted)setState(()=>_loadingProfile=false);
  }

  Color _color(String h){
    final s=h.replaceAll('#','');
    return Color(int.parse('FF$s',radix:16));
  }

  Future<void> _pickPhoto() async {
    try{
      final x=await ImagePicker().pickImage(source:ImageSource.gallery,
        maxWidth:512,maxHeight:512,imageQuality:80);
      if(x==null)return;
      final bytes=await x.readAsBytes();
      final mime=x.name.toLowerCase().endsWith('.png')?'image/png':'image/jpeg';
      setState(()=>_profilePhotoDataUrl='data:$mime;base64,${base64Encode(bytes)}');
      setState(()=>_photoChanged=true);
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Could not pick photo: $e'),backgroundColor:Colors.redAccent));
    }
  }

  void _removePhoto()=>setState(()=>{_profilePhotoDataUrl=null,_photoChanged=true});

  Future<bool> _saveProfile({String? passwordOverride}) async {
    if(_firstNameController.text.trim().isEmpty||
      _lastNameController.text.trim().isEmpty||
      _usernameController.text.trim().isEmpty||
      _emailController.text.trim().isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('First name, last name, username and email are required'),
        backgroundColor:Colors.redAccent)); return false;
    }
    final a=context.read<AuthService>(); final id=a.userId;
    setState(()=>_saving=true);
    try{
      final body={
        'firstName':_firstNameController.text.trim(),
        'middleName':_middleNameController.text.trim(),
        'lastName':_lastNameController.text.trim(),
        'username':_usernameController.text.trim(),
        'email':_emailController.text.trim(),
        'avatarColor':_avatarColorHex,
        if(passwordOverride!=null&&passwordOverride.trim().isNotEmpty)
          'password':passwordOverride.trim(),
        if(_photoChanged)'profilePhoto':_profilePhotoDataUrl,
      };
      final r=await http.put(Uri.parse('$_baseUrl/employees/$id/profile'),
        headers:{'Content-Type':'application/json','Authorization':'Bearer ${a.token}'},
        body:jsonEncode(body));
      final d=jsonDecode(r.body);
      if(r.statusCode==200&&d['success']==true){
        _photoChanged=false; await a.refreshUserData();
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Settings saved successfully!'),
          backgroundColor:Color(0xFF00A854)));
        return true;
      }
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(d['message']??'Could not save settings'),
        backgroundColor:Colors.redAccent));
      return false;
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Connection error: $e'),backgroundColor:Colors.redAccent));
      return false;
    }finally{if(mounted)setState(()=>_saving=false);}
  }

  void _changePassword(){
    final cur=TextEditingController(),neu=TextEditingController(),con=TextEditingController();
    showDialog(context:context,builder:(dc)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
      title:Row(children:[
        _iconBox(Icons.lock_reset_rounded,primary),
        const SizedBox(width:12),const Expanded(child:Text('Change Password',
          style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:text))),
      ]),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        _password(cur,'Current Password',Icons.lock_outline_rounded),
        const SizedBox(height:12),_password(neu,'New Password',Icons.password_rounded),
        const SizedBox(height:12),_password(con,'Confirm New Password',Icons.verified_user_outlined),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('Cancel',
          style:TextStyle(color:muted,fontWeight:FontWeight.w700))),
        ElevatedButton(
          onPressed:()async{
            if(neu.text.trim().isEmpty){
              ScaffoldMessenger.of(dc).showSnackBar(const SnackBar(
                content:Text('Enter a new password'),backgroundColor:Colors.redAccent));return;
            }
            if(neu.text!=con.text){
              ScaffoldMessenger.of(dc).showSnackBar(const SnackBar(
                content:Text('Passwords do not match'),backgroundColor:Colors.redAccent));return;
            }
            Navigator.pop(dc);await _saveProfile(passwordOverride:neu.text);
          },
          style:_buttonStyle(),child:const Text('Change Password')),
      ],
    ));
  }

  InputDecoration _input(String hint,IconData icon)=>InputDecoration(
    hintText:hint,hintStyle:const TextStyle(color:Color(0xFFA4AEC0),fontSize:13),
    prefixIcon:Icon(icon,size:19,color:Color(0xFF8995AA)),filled:true,
    fillColor:const Color(0xFFFBFCFE),
    contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
      borderSide:const BorderSide(color:border)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
      borderSide:const BorderSide(color:border)),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),
      borderSide:const BorderSide(color:primary,width:1.5)));

  Widget _password(TextEditingController c,String l,IconData i)=>TextField(
    controller:c,obscureText:true,decoration:_input(l,i));

  ButtonStyle _buttonStyle()=>ElevatedButton.styleFrom(
    backgroundColor:primary,foregroundColor:Colors.white,elevation:0,
    padding:const EdgeInsets.symmetric(horizontal:20,vertical:13),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)));

  static Widget _iconBox(IconData i,Color c)=>Container(width:42,height:42,
    decoration:BoxDecoration(color:c.withOpacity(.09),borderRadius:BorderRadius.circular(13)),
    child:Icon(i,color:c,size:21));

  @override Widget build(BuildContext context)=>AdminLayout(
    pageTitle:'Settings',currentRoute:'/settings',
    child:Container(color:bg,child:_loadingProfile
      ? const Center(child:Padding(padding:EdgeInsets.all(100),
          child:CircularProgressIndicator()))
      :LayoutBuilder(builder:(context,box){
        final mobile=box.maxWidth<700;
        return SingleChildScrollView(
          physics:const BouncingScrollPhysics(),
          padding:EdgeInsets.fromLTRB(mobile?16:30,mobile?14:24,mobile?16:30,40),
          child:Center(child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:1180),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              _header(mobile),const SizedBox(height:20),
              _profile(mobile),const SizedBox(height:18),
              _section(Icons.person_outline_rounded,primary,'Personal Information',
                'Update the name displayed across your GoDigital account.',
                _personal(mobile)),
              const SizedBox(height:18),
              _section(Icons.manage_accounts_outlined,const Color(0xFF7C3AED),
                'Account Information','Manage your username and email address.',
                _account(mobile)),
              const SizedBox(height:18),
              _section(Icons.badge_outlined,const Color(0xFF0891B2),
                'Work Information','These details are controlled by the main admin.',
                _work(mobile)),
              const SizedBox(height:18),_security(mobile),
              const SizedBox(height:24),_actions(mobile),
              const SizedBox(height:18),
              const Center(child:Text('GoDigital • Account Settings',
                style:TextStyle(fontSize:11,color:muted))),
            ]),
          )),
        );
      }),
    ),
  );

  Widget _header(bool m)=>Container(
    padding:EdgeInsets.symmetric(horizontal:m?18:26,vertical:m?20:24),
    decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[dark,primary]),
      borderRadius:BorderRadius.circular(22),
      boxShadow:[BoxShadow(color:primary.withOpacity(.18),blurRadius:24,offset:const Offset(0,10))]),
    child:Row(children:[
      Container(width:m?46:54,height:m?46:54,
        decoration:BoxDecoration(color:Colors.white.withOpacity(.13),
          borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.white24)),
        child:const Icon(Icons.settings_rounded,color:Colors.white,size:25)),
      const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text('Settings',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),
          SizedBox(height:4),Text('Manage your profile and account preferences.',
            style:TextStyle(color:Colors.white70,fontSize:13,fontWeight:FontWeight.w500)),
        ])),
    ]),
  );

  Widget _profile(bool m){
    final photo=_photo();
    final initials=((_firstNameController.text.isNotEmpty?_firstNameController.text[0]:'')+
      (_lastNameController.text.isNotEmpty?_lastNameController.text[0]:'')).toUpperCase();
    final name=[_firstNameController.text.trim(),_middleNameController.text.trim(),
      _lastNameController.text.trim()].where((x)=>x.isNotEmpty).join(' ');
    final content=Column(crossAxisAlignment:m?CrossAxisAlignment.center:CrossAxisAlignment.start,
      children:[
        Text(name.isEmpty?'Your Profile':name,textAlign:m?TextAlign.center:TextAlign.left,
          style:TextStyle(fontSize:m?20:22,fontWeight:FontWeight.w900,color:text)),
        const SizedBox(height:5),
        Text(_emailController.text.trim().isEmpty?'Add your email address':_emailController.text.trim(),
          textAlign:m?TextAlign.center:TextAlign.left,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:12.5,color:muted,fontWeight:FontWeight.w500)),
        if(_role.isNotEmpty)Padding(padding:const EdgeInsets.only(top:9),
          child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
            decoration:BoxDecoration(color:const Color(0xFFEAF2FF),borderRadius:BorderRadius.circular(30)),
            child:Text(_role,style:const TextStyle(color:primary,fontSize:11,fontWeight:FontWeight.w800)))),
      ]);
    final tools=Column(crossAxisAlignment:m?CrossAxisAlignment.center:CrossAxisAlignment.end,
      children:[_photoButtons(),const SizedBox(height:12),_colors()]);
    return Container(padding:EdgeInsets.all(m?18:24),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),
        border:Border.all(color:border),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.035),
          blurRadius:18,offset:const Offset(0,7))]),
      child:m?Column(children:[
        _avatar(photo,initials,46),const SizedBox(height:14),content,
        const SizedBox(height:17),tools
      ]):Row(children:[
        _avatar(photo,initials,50),const SizedBox(width:20),Expanded(child:content),
        const SizedBox(width:20),SizedBox(width:430,child:tools)
      ]));
  }

  ImageProvider? _photo(){
    if(_profilePhotoDataUrl==null)return null;
    try{return MemoryImage(base64Decode(_profilePhotoDataUrl!.split(',').last));}catch(_){return null;}
  }

  Widget _avatar(ImageProvider? p,String initials,double r)=>Stack(clipBehavior:Clip.none,children:[
    Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(shape:BoxShape.circle,
      border:Border.all(color:_color(_avatarColorHex).withOpacity(.28),width:2)),
      child:CircleAvatar(radius:r,backgroundColor:_color(_avatarColorHex),backgroundImage:p,
        child:p==null?Text(initials.isEmpty?'?':initials,
          style:TextStyle(color:Colors.white,fontSize:r*.58,fontWeight:FontWeight.w900)):null)),
    Positioned(right:-2,bottom:3,child:Container(width:25,height:25,
      decoration:BoxDecoration(color:primary,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3)),
      child:const Icon(Icons.camera_alt_rounded,size:12,color:Colors.white))),
  ]);

  Widget _photoButtons()=>Wrap(alignment:WrapAlignment.end,spacing:8,children:[
    OutlinedButton.icon(onPressed:_pickPhoto,icon:const Icon(Icons.cloud_upload_outlined,size:17),
      label:Text(_profilePhotoDataUrl!=null?'Change Photo':'Upload Photo'),
      style:OutlinedButton.styleFrom(foregroundColor:primary,side:const BorderSide(color:Color(0xFFCAD8F0)),
        padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))),
    if(_profilePhotoDataUrl!=null)TextButton.icon(onPressed:_removePhoto,
      icon:const Icon(Icons.delete_outline_rounded,size:17),label:const Text('Remove'),
      style:TextButton.styleFrom(foregroundColor:Color(0xFFDC2626))),
  ]);

  Widget _colors()=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
    decoration:BoxDecoration(color:const Color(0xFFF8FAFD),borderRadius:BorderRadius.circular(14),
      border:Border.all(color:border)),
    child:Wrap(alignment:WrapAlignment.end,crossAxisAlignment:WrapCrossAlignment.center,
      spacing:8,runSpacing:7,children:[
        const Text('Initials color',style:TextStyle(fontSize:11,color:muted,fontWeight:FontWeight.w700)),
        ..._avatarColorOptions.map((h){
          final s=h==_avatarColorHex;
          return GestureDetector(onTap:()=>setState(()=>_avatarColorHex=h),
            child:AnimatedContainer(duration:const Duration(milliseconds:160),
              width:s?28:24,height:s?28:24,
              decoration:BoxDecoration(color:_color(h),shape:BoxShape.circle,
                border:Border.all(color:Colors.white,width:2),
                boxShadow:[BoxShadow(color:_color(h).withOpacity(.25),blurRadius:5)]),
              child:s?const Icon(Icons.check_rounded,color:Colors.white,size:15):null));
        }),
      ]));

  Widget _section(IconData i,Color c,String title,String sub,Widget child)=>Container(
    width:double.infinity,padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
      border:Border.all(color:border),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.025),
        blurRadius:15,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[_iconBox(i,c),const SizedBox(width:12),Expanded(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(color:text,fontSize:16,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),Text(sub,style:const TextStyle(color:muted,fontSize:11.5)),
        ]))]),const SizedBox(height:21),child]));

  Widget _personal(bool m)=>Column(children:[
    _row(m,_field('First Name',_firstNameController,Icons.person_outline_rounded),
      _field('Middle Name',_middleNameController,Icons.person_outline_rounded,false)),
    SizedBox(height:m?14:16),_field('Last Name',_lastNameController,Icons.person_outline_rounded)
  ]);

  Widget _account(bool m)=>_row(m,
    _field('Username',_usernameController,Icons.alternate_email_rounded),
    _field('Email Address',_emailController,Icons.email_outlined));

  Widget _work(bool m)=>_row(m,_locked('Employee ID',_staffId.isEmpty?'—':_staffId),
    _locked('Role',_role.isEmpty?'—':_role));

  Widget _row(bool m,Widget a,Widget b)=>m?Column(children:[a,const SizedBox(height:14),b]):
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:a),
      const SizedBox(width:16),Expanded(child:b)]);

  Widget _field(String label,TextEditingController c,IconData i,[bool required=true])=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Text(label,style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:text)),
        if(required)const Text(' *',style:TextStyle(color:Color(0xFFDC2626),fontWeight:FontWeight.w800))]),
      const SizedBox(height:7),TextField(controller:c,onChanged:(_)=>setState((){}),
        style:const TextStyle(fontSize:13.5,color:text,fontWeight:FontWeight.w600),
        cursorColor:primary,decoration:_input('Enter $label',i)),
    ]);

  Widget _locked(String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Text(label,style:const TextStyle(fontSize:12.5,fontWeight:FontWeight.w800,color:text)),
      const SizedBox(width:6),const Icon(Icons.lock_outline_rounded,size:14,color:Color(0xFF9AA5B5))]),
    const SizedBox(height:7),Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
      decoration:BoxDecoration(color:const Color(0xFFF2F5F9),borderRadius:BorderRadius.circular(13),
        border:Border.all(color:border)),child:Row(children:[
          Icon(label=='Role'?Icons.work_outline_rounded:Icons.badge_outlined,size:18,color:const Color(0xFF8995AA)),
          const SizedBox(width:10),Expanded(child:Text(value,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:13.5,color:muted,fontWeight:FontWeight.w700))),
          const Icon(Icons.lock_rounded,size:14,color:Color(0xFFB3BCC9))
        ])),
  ]);

  Widget _security(bool m)=>Container(width:double.infinity,padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:border)),
    child:m?Column(children:[
      Row(children:[_iconBox(Icons.shield_outlined,const Color(0xFFD97706)),const SizedBox(width:13),
        const Expanded(child:Text('Password & Security',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900)))]),
      const SizedBox(height:10),const Text('Keep your account secure with a strong password.',
        style:TextStyle(color:muted,fontSize:11.5)),const SizedBox(height:13),
      SizedBox(width:double.infinity,child:OutlinedButton(onPressed:_changePassword,
        style:OutlinedButton.styleFrom(foregroundColor:primary,side:const BorderSide(color:Color(0xFFCAD8F0)),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:const Text('Change Password')))
    ]):Row(children:[
      _iconBox(Icons.shield_outlined,const Color(0xFFD97706)),const SizedBox(width:14),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Password & Security',style:TextStyle(color:text,fontSize:15,fontWeight:FontWeight.w900)),
        SizedBox(height:3),Text('Keep your account secure with a strong password.',
          style:TextStyle(color:muted,fontSize:11.5))])),
      OutlinedButton(onPressed:_changePassword,style:OutlinedButton.styleFrom(foregroundColor:primary,
        side:const BorderSide(color:Color(0xFFCAD8F0)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        child:const Text('Change'))
    ]));

  Widget _actions(bool m)=>m?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _save(),const SizedBox(height:10),_cancel()
  ]):Row(mainAxisAlignment:MainAxisAlignment.end,children:[
    _cancel(),const SizedBox(width:12),_save()
  ]);

  Widget _save()=>ElevatedButton.icon(onPressed:_saving?null:()=>_saveProfile(),
    icon:_saving?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):
      const Icon(Icons.check_circle_outline_rounded,size:18),
    label:Text(_saving?'Saving...':'Save Settings'),
    style:ElevatedButton.styleFrom(backgroundColor:primary,foregroundColor:Colors.white,elevation:0,
      padding:const EdgeInsets.symmetric(horizontal:24,vertical:15),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
      textStyle:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)));

  Widget _cancel()=>OutlinedButton(onPressed:()=>Navigator.pop(context),
    style:OutlinedButton.styleFrom(foregroundColor:text,backgroundColor:Colors.white,
      side:const BorderSide(color:border),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
      padding:const EdgeInsets.symmetric(horizontal:24,vertical:15)),
    child:const Text('Cancel',style:TextStyle(fontWeight:FontWeight.w800)));
}
