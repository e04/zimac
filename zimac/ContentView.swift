import SwiftUI

class ResultData: ObservableObject {
    @Published var text = "ここに結果が表示されます"
}

struct ContentView: View {
    @ObservedObject var resultData: ResultData

    var body: some View {
        HStack{
            ScrollViewReader { proxy in
                ScrollView {
                    HStack{
                        VStack {
                            Text(resultData.text)
                                .font(.system(size: 24.0))
                                .multilineTextAlignment(.leading)
                                .padding(4.0)
                            Spacer().id("bottom")
                        }
                        Spacer()
                    }
                }.frame(minWidth: 400, minHeight: 200)
                    .onChange(of: resultData.text) { id in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
            }
            VStack{
                Button(action: start, label: {
                    Text("Start")
                })
                Button(action: stop, label: {
                    Text("Stop")
                })
            }

        }
    }
                
    func start() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.prepRecord()
    }
    
    func stop() {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.stopRecording()
    }
}

#Preview {
    ContentView(resultData: ResultData())
}

