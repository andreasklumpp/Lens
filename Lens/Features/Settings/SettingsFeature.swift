import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var ollamaURL: String = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        var modelName: String = UserDefaults.standard.string(forKey: "modelName") ?? "llama3.2"
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}
