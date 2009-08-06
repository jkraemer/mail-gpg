# encoding: utf-8
# 
#    The "Message-ID:" field provides a unique message identifier that
#    refers to a particular version of a particular message.  The
#    uniqueness of the message identifier is guaranteed by the host that
#    generates it (see below).  This message identifier is intended to be
#    machine readable and not necessarily meaningful to humans.  A message
#    identifier pertains to exactly one instantiation of a particular
#    message; subsequent revisions to the message each receive new message
#    identifiers.
# 
#    Note: There are many instances when messages are "changed", but those
#    changes do not constitute a new instantiation of that message, and
#    therefore the message would not get a new message identifier.  For
#    example, when messages are introduced into the transport system, they
#    are often prepended with additional header fields such as trace
#    fields (described in section 3.6.7) and resent fields (described in
#    section 3.6.6).  The addition of such header fields does not change
#    the identity of the message and therefore the original "Message-ID:"
#    field is retained.  In all cases, it is the meaning that the sender
#    of the message wishes to convey (i.e., whether this is the same
#    message or a different message) that determines whether or not the
#    "Message-ID:" field changes, not any particular syntactic difference
#    that appears (or does not appear) in the message.
module Mail
  class MessageIdField < StructuredField
    
  end
end