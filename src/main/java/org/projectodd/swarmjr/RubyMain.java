package org.projectodd.swarmjr;

import org.jruby.embed.ScriptingContainer;

/**
 * Created by enebo on 10/10/15.
 */
public class RubyMain {
    public static void main(String[] args) throws Exception {
        ScriptingContainer container = new ScriptingContainer();

        container.runScriptlet("puts 'embedded' Ruby");
    }
}
