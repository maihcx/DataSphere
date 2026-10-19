using CommunityToolkit.Mvvm.Messaging;

namespace DataSphere.Services
{
    /// <summary>
    /// Service facilitating decoupled asynchronous message passing and notifications between ViewModels and UI components.
    /// </summary>
    public class MessengerService
    {
        private readonly IMessenger _messenger;

        /// <summary>
        /// Initializes a new instance of the <see cref="MessengerService"/> class using the default WeakReferenceMessenger.
        /// </summary>
        public MessengerService() : this(WeakReferenceMessenger.Default)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="MessengerService"/> class with a custom IMessenger instance.
        /// </summary>
        /// <param name="messenger">The messenger instance to delegate communication through.</param>
        public MessengerService(IMessenger messenger)
        {
            _messenger = messenger ?? throw new ArgumentNullException(nameof(messenger));
        }

        /// <summary>
        /// Sends a message of type <typeparamref name="TMessage"/> to all registered recipients.
        /// </summary>
        /// <typeparam name="TMessage">The type of the message payload.</typeparam>
        /// <param name="message">The message instance to dispatch.</param>
        public void Send<TMessage>(TMessage message) where TMessage : class
        {
            _messenger.Send(message);
        }

        /// <summary>
        /// Registers a recipient to receive messages of type <typeparamref name="TMessage"/>.
        /// </summary>
        /// <typeparam name="TMessage">The type of the message to listen for.</typeparam>
        /// <param name="recipient">The object receiving the messages.</param>
        /// <param name="handler">The callback action executed when a message is received.</param>
        public void Register<TMessage>(object recipient, MessageHandler<object, TMessage> handler) where TMessage : class
        {
            _messenger.Register(recipient, handler);
        }

        /// <summary>
        /// Unregisters a recipient from all received message channels.
        /// </summary>
        /// <param name="recipient">The recipient to unregister.</param>
        public void Unregister(object recipient)
        {
            _messenger.UnregisterAll(recipient);
        }
    }
}
