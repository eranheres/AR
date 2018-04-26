import Foundation
import UIKit
var networkLogic: NetworkLogic!;

class ViewController: UIViewController, DemoView
{
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		networkLogic = NetworkLogic(demoView : self)
		Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.service), userInfo: nil, repeats: true)
		// Do any additional setup after loading the view, typically from a nib.
		statusLabel.text = "Loaded..."
		networkLogic.updateState()
	}

	override func didReceiveMemoryWarning()
	{
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@objc func service()
	{
		networkLogic.service()
	}
	
	@IBOutlet var statusLabel:UILabel!
	@IBOutlet var button:UIButton!
	@IBOutlet var button2:UIButton!
	@IBOutlet var logText:UITextView!
		
	@IBAction func onButton(_ sender: AnyObject)
	{
		networkLogic.onButton();
	}
	
	@IBAction func onButton2(_ sender: AnyObject)
	{
		networkLogic.onButton2()
	}

	func write(_ s : String)
	{
		self.out(s)
	}
	
	func log(_ s : String)
	{
		//self.out(s + "\n")
		print(s)
	}

	fileprivate func out(_ s: String)
	{
		self.logText.text = String(self.logText.text) + s
		//self.logText.layoutIfNeeded()
		self.logText.setContentOffset(CGPoint(x : 0, y : self.logText.contentSize.height - self.logText.bounds.size.height), animated: false)
	
		//	logText.scrollRectToVisible(CGRect(x:0, y:logText.contentSize.height - 30, width:logText.contentSize.width, height:30), animated: false)
	}
	
	func showState(_ state : Int, stateStr : String, roomName : String, playerNr : Int32, inLobby : Bool, inRoom : Bool)
	{
		if (inRoom)
		{
			self.statusLabel.text = String(format:"%@ %@ / %d", stateStr, roomName, playerNr)
		}
		else
		{
			self.statusLabel.text = stateStr;
		}
		if (inLobby) {
			button.setTitle("Join or Create", for: UIControlState())
		} else if (inRoom) {
			button.setTitle("Leave", for: UIControlState())
		} else {
			button.setTitle("Connect", for: UIControlState())
		}
		
		button2.setTitle("Disonnect", for: UIControlState())
	}
}
