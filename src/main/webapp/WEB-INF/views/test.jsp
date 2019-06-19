<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE>

<html>

<head>
<title>WebRTC Video Demo</title>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
</head>

<style>
body {
	background: #eee;
	padding: 5% 0;
}

video {
	background: black;
	border: 1px solid gray;
}

.call-page {
	position: relative;
	display: block;
	margin: 0 auto;
	width: 500px;
	height: 500px;
}

#localVideo {
	width: 150px;
	height: 150px;
	position: absolute;
	top: 15px;
	right: 15px;
}

#remoteVideo {
	width: 500px;
	height: 500px;
}
</style>

<body>

	<div id="loginPage" class="container text-center">

		<div class="row">
			<div class="col-md-4 col-md-offset-4">

				<h2>WebRTC Sample.</h2>
				<label for="usernameInput" class="sr-only">Login</label> <input
					type="email" id="usernameInput" c lass="form-control formgroup"
					placeholder="your name" required="" autofocus="">
				<button id="loginBtn" class="btn btn-lg btn-primary btnblock">
					Login</button>
			</div>
		</div>
		
		<div class="row">
			<h2>사용법</h2>
			<p>1. 로그인에 아이디를 씀 (서버에 이미 있으면 안됨)</p>
			<p>2. 로그인이 완료되면 나오는 페이지에서 상대방이 로그인한 아이디를 씀 (서버에 있는 아이디)</p>
			<p>3. call 버튼을 누르면 상대방과 연결됨 (웹캠이 없다면 연결안됨)</p>
			<p>4. hangup 버튼을 누르면 상대방과 연결 해제되고 초기화됨</p>
			<p>5. 개발자모드로 들어가서 console가서 log 확인하면서 보면 좋음</p>
		</div>

	</div>

	<div id="callPage" class="call-page">
		<video id="localVideo" autoplay></video>
		<video id="remoteVideo" autoplay></video>

		<div class="row text-center">
			<div class="col-md-12">
				<input id="callToUsernameInput" type="text"
					placeholder="username to call" />
				<button id="callBtn" class="btn-success btn">Call</button>
				<button id="hangUpBtn" class="btn-danger btn">Hang Up</button>
			</div>
		</div>

	</div>

	<script>
		//내 이름, 연결된 상대이름
		var name;
		var connectedUser;

		//============================== 소켓서버 ===================================//
		//시그널 서버와 연결
// 		var conn = new WebSocket('wss://'+document.domain+'/ly/webrtcsocket');
		
		var conn = new WebSocket('wss://192.168.207.197/ly/webrtcsocket');
		conn.onopen = function() {
			console.log("시그널 서버와 연결됨");
		};

		//서버로부터 메세지 이벤트 발생
		conn.onmessage = function(msg) {
			console.log("메세지 발생", msg.data);

			var data = JSON.parse(msg.data);

			switch (data.type) {
			case "login":
				handleLogin(data.success);
				break;
			//when somebody wants to call us 
			case "offer":
				handleOffer(data.offer, data.name);
				break;
			case "answer":
				handleAnswer(data.answer);
				break;
			//when a remote peer sends an ice candidate to us 
			case "candidate":
				handleCandidate(data.candidate);
				break;
			case "leave":
				handleLeave();
				break;
			default:
				break;
			}
		};

		// 소켓 에러남
		conn.onerror = function(err) {
			console.log("에러 발생", err);
		};

		// 서버로 메세지 보냄
		function send(message) {
			if (connectedUser) {
				message.name = connectedUser;
			}
			conn.send(JSON.stringify(message));
		};
		//===========================================================================//

		//****** 
		//UI selectors block 
		//******

		//==================================== DOMs ====================================//
		var loginPage = document.querySelector('#loginPage');
		var usernameInput = document.querySelector('#usernameInput');
		var loginBtn = document.querySelector('#loginBtn');

		var callPage = document.querySelector('#callPage');
		var callToUsernameInput = document
				.querySelector('#callToUsernameInput');
		var callBtn = document.querySelector('#callBtn');

		var hangUpBtn = document.querySelector('#hangUpBtn');

		var localVideo = document.querySelector('#localVideo');
		var remoteVideo = document.querySelector('#remoteVideo');
		//==============================================================================//

		callPage.style.display = "none";

		var yourConn; // 내 rtc
		var stream; // 내 stream

		//=================================== user event ==================================//

		// login 버튼 클릭시
		loginBtn.addEventListener("click", function(event) {
			name = usernameInput.value;

			if (name.length > 0) {
				send({
					type : "login",
					name : name
				});
			}

		});

		// call 버튼 클릭시
		callBtn.addEventListener("click", function() {
			var callToUsername = callToUsernameInput.value;

			if (callToUsername.length > 0) {

				connectedUser = callToUsername;

				// 요청데이터 생성
				yourConn.createOffer(function(offer) {
					send({type : "offer",offer : offer});
					yourConn.setLocalDescription(offer);
				}, function(error) {alert("요청데이터 생성 에러");});}
		});

		// hangup 버튼 클릭시
		hangUpBtn.addEventListener("click", function() {
			send({
				type : "leave",
				name : name
			});
			handleLeave();
		});

		//============================================================================//

		//==================================== socket server event ===========================//

		//onlogin
		function handleLogin(success) {
			if (success == "false") {
				alert("이미 있는 이름입니다");
                return;
			} else {
				loginPage.style.display = "none";
				callPage.style.display = "block";

				//********************** 
				//Starting a peer connection 
				//********************** 

				// 내 stream 가져오기
				navigator.mediaDevices.getUserMedia({audio: true, video:true }).then(function(myStream) {
					stream = myStream;

					// 내 stream localVideo에 뿌림
					localVideo.srcObject = myStream;

					// STUN 서버 설정 (Google꺼 사용) 
					var configuration = {
						"iceServers" : [ {
							"url" : "stun:stun2.1.google.com:19302"
						} ]
					};

					yourConn = new RTCPeerConnection(configuration);
					console.log('yourConn =>'+yourConn );
					// rtc에 내 stream 추가하기
					yourConn.addStream(stream);
					
// 					navigator.mediaDevices.getUserMedia({
// 						{ audio: true, video:true }, function(myStream) {
// 						stream = myStream;

// 						// 내 stream localVideo에 뿌림
// 						localVideo.srcObject = myStream;
					
					
					// 상대방과 연결되고 상대방이 stream 보냄 이벤트
					yourConn.onaddstream = function(e) {
						remoteVideo.srcObject = e.stream;
					};

					// ICE 핸들링 설정
					yourConn.onicecandidate = function(event) {
						if (event.candidate) {
							send({
								type : "candidate",
								candidate : event.candidate
							});
						}
					};

				}, function(error) {
					console.log(error);
				});

			}
		};

		// 상대방이 연결요청 보내면
		function handleOffer(offer, name) {
			connectedUser = name;
			yourConn.setRemoteDescription(new RTCSessionDescription(offer));

			// 응답데이터 생성
			yourConn.createAnswer(function(answer) {
				yourConn.setLocalDescription(answer);

				send({
					type : "answer",
					answer : answer
				});

			}, function(error) {
				alert("응답데이터 생성 에러");
			});
		};

		// 상대방으로부터 응답데이터 오면
		function handleAnswer(answer) {
			yourConn.setRemoteDescription(new RTCSessionDescription(answer));
		};

		// 상대방으로부터 ICE candidate 오면
		function handleCandidate(candidate) {
			yourConn.addIceCandidate(new RTCIceCandidate(candidate));
		};

		// onleave
		function handleLeave() {
				conn.close();
				window.location.reload();
		};

		//==================================== socket server event ===========================//
	</script>

</body>

</html>
