import Foundation

let DemoEventCode0 : nByte = 0

let PeerStatesStr : [String] =
[
	"Uninitialized",
	"PeerCreated",
	"ConnectingToNameserver",
	"ConnectedToNameserver",
	"DisconnectingFromNameserver",
	"Connecting",
	"Connected",
	"WaitingForCustomAuthenticationNextStepCall",
	"Authenticated",
	"JoinedLobby",
	"DisconnectingFromMasterserver",
	"ConnectingToGameserver",
	"ConnectedToGameserver",
	"AuthenticatedOnGameServer",
	"Joining",
	"Joined",
	"Leaving",
	"Left",
	"DisconnectingFromGameserver",
	"ConnectingToMasterserver",
	"ConnectedComingFromGameserver",
	"AuthenticatedComingFromGameserver",
	"Disconnecting",
	"Disconnected",
];

protocol PhotonDelegateView
{
	func log(_: String) -> Void
    func showState(_ state : Int, stateStr : String, roomName : String, playerNr : Int32, inLobby : Bool, inRoom : Bool)
}

class PhotonListener : NSObject, EGLoadBalancingListener
{
	var networkLogic : NetworkLogic!
	let delegateView : PhotonDelegateView
    var delegateTransportLayer : NetworkTransportLayerDelegate?
    
    init(networkLogic : NetworkLogic, demoView : PhotonDelegateView)
	{
		self.networkLogic = networkLogic
		self.delegateView = demoView
		super.init()
	}
	
	func debugReturn(_ debugLevel : Int32, _ string : String!) -> Void
	{
		self.delegateView.log(string)
	}
	
	func connectionErrorReturn(_ errorCode : Int32) -> Void
	{
		self.delegateView.log(String(format: "- connectionErrorReturn: %d", errorCode))
		networkLogic.updateState()
	}
	
	func clientErrorReturn(_ errorCode : Int32) -> Void
	{
		self.delegateView.log(String(format: "- clientErrorReturn: %d", errorCode))
		networkLogic.updateState()
	}
	
	func warningReturn(_ warningCode : Int32)-> Void
	{
		self.delegateView.log(String(format: "- warningReturn: %d", warningCode))
		networkLogic.updateState()
	}
	
	func serverErrorReturn(_ errorCode : Int32) -> Void
	{
		self.delegateView.log(String(format: "- serverErrorReturn: %d", errorCode))
		networkLogic.updateState()
	}

	// events, triggered by certain operations of all players in the same room
	func joinRoomEventAction(_ playerNr : Int32, _ playernrs : EGArray!, _ player : EGLoadBalancingPlayer!) -> Void
	{
		self.delegateView.log(String(format: "- joinRoomEventAction: %d", playerNr ))
		networkLogic.updateState()
	}
	
	func leaveRoomEventAction(_ playerNr : Int32, _ isInactive : Bool) -> Void
	{
		self.delegateView.log(String(format: "- leaveRoomEventAction: %d %s", playerNr, isInactive ? "true" : "false" ))
		networkLogic.updateState()
	}
	
	func disconnectEventAction(_ playerNr : Int32) -> Void
	{
		self.delegateView.log(String(format: "- leaveRoomEventAction: %d", playerNr))
		networkLogic.updateState()
	}

	// callbacks for operations on server
	func connectReturn(_ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- connectReturn: %d %@", errorCode, errorString ?? ""))
		networkLogic.updateState()
	}
	
	func disconnectReturn() -> Void
	{
		self.delegateView.log(String(format: "- disconnectReturn"))
		networkLogic.updateState()
	}
	
	func createRoomReturn(_ localPlayerNr : Int32, _ roomProperties : [AnyHashable: Any]!, _ playerProperties : [AnyHashable: Any]!, _ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- createRoomReturn: %d %@ %@ %d %@", localPlayerNr, roomProperties ?? "", playerProperties ?? "", errorCode, errorString ?? ""))
		networkLogic.updateState()
	}

	func joinOrCreateRoomReturn(_ localPlayerNr : Int32, _ roomProperties : [AnyHashable: Any]!,  _ playerProperties : [AnyHashable: Any]!, _ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- joinOrCreateRoomReturn: %d %@ %@ %d %@", localPlayerNr, roomProperties ?? "", playerProperties ?? "", errorCode, errorString ?? ""))
		networkLogic.updateState()
	}
	
	func joinRoomReturn(_ localPlayerNr : Int32, _ roomProperties : [AnyHashable: Any]!, _ playerProperties : [AnyHashable: Any]!, _ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- joinRoomReturn: %d %@ %@ %d %@", localPlayerNr, roomProperties ?? "", playerProperties ?? "", errorCode, errorString ?? ""))
		networkLogic.updateState()
	}
	
	func leaveRoomReturn(_ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- leaveRoomReturn: %d %@", errorCode, errorString ?? ""))
		networkLogic.updateState()
	}
	
	func joinLobbyReturn() -> Void
	{
		self.delegateView.log(String(format: "- joinLobbyReturn"))
		networkLogic.updateState()
	}
	
	func leaveLobbyReturn() -> Void
	{
		self.delegateView.log(String(format: "- leaveLobbyReturn"))
		networkLogic.updateState()
	}
		
	func joinRandomRoomReturn(_ localPlayerNr : Int32, _ roomProperties : [AnyHashable: Any]!, _ playerProperties : [AnyHashable: Any]!, _ errorCode : Int32, _ errorString : String!) -> Void
	{
		self.delegateView.log(String(format: "- joinRandomRoomReturn: %d %@ %@ %d %@", localPlayerNr, roomProperties ?? "", playerProperties ?? "", errorCode, errorString ?? ""))
		if(errorCode != 0)
		{
			networkLogic.createRoom()
		}
		networkLogic.updateState()
	}
	
	func customEventAction(_ playerNr : Int32, _ eventCode : nByte,  _ eventContent : NSObject) -> Void
	{
			if(eventContent is NSString)
			{
				let v = eventContent as! NSString;
                let s = v as String
                // self.delegateView.log("msg:p-\(playerNr):"+s)
                self.delegateTransportLayer?.handleRx(messageId: UInt8(eventCode), message: s)
//               self.delegateView.messageReceived(s)
			}
	}
    
}

class NetworkLogic : NetworkTransportLayerDelegate, NetworkTransportLayerProtocol
{
	var client : EGLoadBalancingClient!
	let demoView : PhotonDelegateView
	var listenerRef : PhotonListener! // store reference to prevent listener destroy
    let netApplicationLayer : NetworkApplicationLayer
    	
    init(demoView : PhotonDelegateView, networkApplicationLayer: NetworkApplicationLayer)
	{
		self.demoView = demoView
        self.netApplicationLayer = networkApplicationLayer
        listenerRef = PhotonListener(networkLogic: self, demoView : demoView)
        netApplicationLayer.transportLayer = self
        listenerRef.delegateTransportLayer = self
		self.client = EGLoadBalancingClient(client : listenerRef, appId, appVersion)
		self.client.debugOutputLevel = EGDebugLevel_WARNINGS
	}
    
    func handleRx(messageId: UInt8, message: String) {
        // demoView.log("rx:\(messageId):"+message)
        netApplicationLayer.handleRx(msgId: messageId, str: message)
    }
    
    func sendMessage(messageId: UInt8, message: String) {
        if(client.isInGameRoom) {
            // demoView.log("tx:\(messageId):"+message)
            let v = message as NSString
            client.opRaiseEvent(true, v, messageId)
        }
    }
	
	func service()
	{
		autoreleasepool
		{
			client.service()
		}
	}
	
	func createRoom()
	{
        demoView.log("Photon: creating room...")
        client.opJoinOrCreateRoom("Shooter Demo")
	}
	
	func updateState()
	{
		var room = ""
		if(client.isInGameRoom)
		{
			room = client.currentlyJoinedRoom.name
		}
		var stateStr = ""
		if(Int(client.state) < PeerStatesStr.count)
		{
			stateStr = PeerStatesStr[Int(client.state)]
		}
        var localPlayerNum :Int32 = -1
        if (client.localPlayer != nil) {
            localPlayerNum = client.localPlayer.number
        }
        
		demoView.showState(Int(client.state), stateStr : String(format : "StateStr[%@/%d]", stateStr, client.state), roomName : room, playerNr : localPlayerNum, inLobby : client.isInLobby, inRoom : client.isInGameRoom)
	}
    
    func joinRandomRoom() {
        demoView.log("joining...")
        client.opJoinRandomRoom()
    }
    
    
    
    func leaveRoom() {
        demoView.log("leaving...")
        client.opLeaveRoom()
    }
    
    func connect() {
        demoView.log("connecting...")
        client.connect()
    }
    
    func disconnect() {
        demoView.log("disconnecting...")
        client.disconnect()
    }
	
}
