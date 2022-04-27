defmodule FlowitWeb.CanvasLive do
  alias Flowit.FileInterface
  @height_unit 100
  @width_unit 120
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_view
  use FlowitWeb, :live_view





  def mount(_params, %{}, socket) do
    res = Agent.start(fn -> %{} end, name: :flow_reg)
    flows = Agent.get(:flow_reg, fn x -> x end)
    flows = %{}

    {:ok,
     assign(socket,
       myheight: @height_unit,
       flow: nil,
       flow_name_suggestion: "myflow",
       flows: flows
     )}
  end

  @impl true
  def handle_params(%{"flow" => flow}, _uri, socket) do
    # flow = flow_file
    {:noreply, assign(socket, flow: socket.assigns.flows[flow])}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}


  def handle_event("generate_counter_flow", _, socket) do
    {_, socket} = handle_event("create_flow", %{"flowname" => "counter_flow"}, socket)
    socket = assign(socket, flow: socket.assigns.flows["counter_flow"])
    {_, socket} = handle_event("add_view", %{"name" => "counter_view", "dispatched_by_id" => nil}, socket)
    id = socket.assigns.flow["components"] |> Enum.at(0) |> Map.get("gui_id")
    {_, socket} = handle_event("add_command", %{"command" => "increment", "dispatched_by_id" => id, "command_params" => ""}, socket)
    id = socket.assigns.flow["components"] |> Enum.at(1) |> Map.get("gui_id")
    {_, socket} = handle_event("add_event", %{"event" => "incremented", "dispatched_by_id" => id, "event_params" => "", "aggregate" => "counter_aggregate"}, socket)
    id = socket.assigns.flow["components"] |> Enum.at(2) |> Map.get("gui_id")
    {_, socket} = handle_event("add_read_model", %{"read_model" => "counters", "dispatched_by_id" => id}, socket)


    id = socket.assigns.flow["components"] |> Enum.at(4) |> Map.get("gui_id")
    {_, socket} = handle_event("add_view", %{"name" => "counter_view", "dispatched_by_id" => id}, socket)
    {_, socket} = handle_event("generate_files", %{"app_name" => "FlowitTest"}, socket)

    {:noreply, socket}

  end


  def handle_event("set_flow", %{"flow" => flow}, socket) do
    {:noreply, push_patch(socket, to: "/flows/#{flow}")}
  end

  def handle_event("create_flow", %{"flowname" => flowname}, socket) do
    # This is sent when  I press close on set flow modal, It should not.. but this works for now
    if flowname == "" do
      {:noreply, socket}
    else
      case Map.get(socket.assigns.flows, flowname) do
        nil ->
          flows =
            Map.put(socket.assigns.flows, flowname, %{"name" => flowname, "components" => []})

          Agent.update(:flow_reg, fn x -> flows end)
          {:noreply, assign(socket, flows: flows)}

        _x ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("add_view", %{"name" => name, "dispatched_by_id" => dispatched_by_id}, socket) do
    dispatched_by_component =
      Enum.find(socket.assigns.flow["components"], fn component ->
        dispatched_by_id == component["gui_id"]
      end)
      |> (fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end).()

    component = [
      %{
        "type" => "view",
        "name" => name,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  defp update_flow(component, socket) do
    components = socket.assigns.flow["components"] ++ component
    flow = Map.put(socket.assigns.flow, "components", components)
    flows = Map.put(socket.assigns.flows, flow["name"], flow)
    Agent.update(:flow_reg, fn _x -> flows end)
    {:noreply, assign(socket, flows: flows, flow: flow)}
  end

  @impl true
  def handle_event(
        "add_command",
        %{
          "command" => command,
          "command_params" => command_params,
          "dispatched_by_id" => dispatched_by_id
        },
        socket
      ) do
    dispatched_by_component =
      Enum.find(socket.assigns.flow["components"], fn component ->
        dispatched_by_id == component["gui_id"]
      end)
      |> (fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end).()

    component = [
      %{
        "type" => "command",
        "name" => command,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "command_params" => command_params,
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_event",
        %{
          "event" => event,
          "event_params" => event_params,
          "aggregate" => aggregate,
          "dispatched_by_id" => dispatched_by_id
        },
        socket
      ) do

    dispatched_by_component =
      Enum.find(socket.assigns.flow["components"], fn component ->
        dispatched_by_id == component["gui_id"]
      end)
      |> (fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end).()

    event_component =
      %{
        "type" => "event",
        "name" => event,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "event_params" => event_params,
        "gui_id" => UUID.uuid1(),
        "aggregate" => aggregate
      }

      component =
      # case Enum.find(socket.assigns.flow["components"], fn comp -> comp["type"] == "aggregate" && comp["name"] == aggregate end) do
        # nil ->
          [event_component,
           	%{"type" => "aggregate",
           	"name" => aggregate,
           	"dispatched_by_component" => [event_component]
           	}
           ]
       # 	x ->
       #   	IO.puts "existing component is"
       #   	IO.inspect x

       #   	[event_component, Map.put(x, "dispatched_by_component", x["dispatched_by_component"] ++ event_component)]
       # end

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_read_model",
        %{"read_model" => read_model, "dispatched_by_id" => dispatched_by_id},
        socket
      ) do
    dispatched_by_component =
      Enum.find(socket.assigns.flow["components"], fn component ->
        dispatched_by_id == component["gui_id"]
      end)
      |> (fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end).()

    component = [
      %{
        "type" => "read_model",
        "name" => read_model,
        "dispatched_by_component" => [dispatched_by_component],
        "dispatched_by_id" => dispatched_by_id,
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  @impl true
  def handle_event(
        "add_processer",
        %{"processer" => processer, "dispatched_by_id" => dispatched_by_id},
        socket
      ) do
    dispatched_by_component =
      Enum.find(socket.assigns.flow["components"], fn component ->
        dispatched_by_id == component["gui_id"]
      end)
      |> (fn comp -> %{"name" => comp["name"], "type" => comp["type"]} end).()

    component = [
      %{
        "type" => "processer",
        "name" => processer,
        "dispatched_by_id" => dispatched_by_id,
        "dispatched_by_component" => [dispatched_by_component],
        "gui_id" => UUID.uuid1()
      }
    ]

    update_flow(component, socket)
  end

  def handle_event("generate_files", %{"app_name" => app_name}, socket) do
    app_name = "FlowitTest"
    flow = socket.assigns.flows |> Map.values() |> Enum.at(0)

    merge_dispatched_by =
      flow["components"]
      |> Enum.reduce(%{}, fn component, acc ->
        case Map.get(acc, component["name"]) do
          nil ->
            Map.put(acc, component["name"], component)

          x ->
            IO.puts "prining a round"
            IO.inspect x["name"]
            IO.inspect x["type"]
            IO.inspect x["dispatched_by_component"]

            IO.inspect "component is"
            IO.inspect component["dispatched_by_component"]
            IO.inspect component


            disp_by_name = nil_to_empty_array(x["dispatched_by_component"]) ++ component["dispatched_by_component"]
           		new_comp = Map.put(component, "dispatched_by_component", disp_by_name)
           		new_comp = case component["type"] do
             		"command" -> merged_command_params = Map.merge(component["command_params"], x["command_params"])
             								 Map.put(new_comp, "command_params", merged_command_params)
             		"event" -> merged_event_params = Map.merge(component["event_params"], x["event_params"])
             								 Map.put(new_comp, "event_params", merged_event_params)


             	  _ -> new_comp
             	  end

            	Map.put(acc, component["name"], new_comp)
        end
      end)

    components_with_dispatched =
      Map.values(merge_dispatched_by)
      |> Enum.reduce(merge_dispatched_by, fn component, acc ->
        components_dispatched_by_me =
          Enum.filter(Map.values(merge_dispatched_by), fn comp ->
            Enum.member?(
              Enum.map(comp["dispatched_by_component"], fn comp -> comp["name"] end),
              component["name"]
            )
          end)
          # |> Enum.map(fn full_comp ->
          #   %{"name" => full_comp["name"], "type" => full_comp["type"]}
          # end)

        updated_comp =
          Map.get(acc, component["name"])
          |> Map.put("dispatches", components_dispatched_by_me)

        Map.put(acc, component["name"], updated_comp)
      end)

    IO.inspect("components with dispatched by me")
    IO.inspect(components_with_dispatched)

    id = UUID.uuid1()

    res = File.mkdir_p("#{id}/flowit_scaffold")
    res = File.mkdir_p("#{id}/flowit_scaffold/views")
    res = File.mkdir_p("#{id}/flowit_scaffold/commands")
    res = File.mkdir_p("#{id}/flowit_scaffold/events")
    res = File.mkdir_p("#{id}/flowit_scaffold/aggregates")
    res = File.mkdir_p("#{id}/flowit_scaffold/read_models")
    res = File.mkdir_p("#{id}/flowit_scaffold/processes")
    res = File.mkdir_p("#{id}/flowit_scaffold/base")

    generate_base(id, app_name)
    generate_aggregate_macro(id)
    generate_read_model_macro(id)
    generate_supervisor(id, Map.values(components_with_dispatched))


    components_with_dispatched
    |> Map.values()
    |> Enum.each(fn comp ->
      IO.puts("comp is")
      IO.inspect(comp)
      file_name = comp["name"]

      case comp["type"] do
        "view" -> generate_view_file(app_name, id, file_name,comp)
        "command" -> generate_command_file(app_name, id, file_name, comp)
        "aggregate" -> genereate_aggregates(app_name, id, file_name, comp)
        "event" -> generate_event_file(app_name, id, file_name, comp)
        "read_model" -> generate_read_model_file(app_name, id, file_name, comp)
        _ -> nil
      end
    end)

    res = System.cmd("zip", ["-r", "priv/static/boilerplates/#{id}.zip", "#{id}/flowit_scaffold/"])

    System.cmd("cp", ["-rf", "#{id}/flowit_scaffold", "/home/ask/delme/flowit_test/lib/"])
    System.cmd("rm", ["-rf", "#{id}"])
    # File.cp_r("#{id}/flowit_scaffold/*", "/home/ask/delme/flowit_test/lib/flowit_scaffold/")
    # File.cp_
    {:noreply, socket |> redirect(to: "/boilerplates/#{id}.zip")}
  end



	defp generate_read_model_file(app_name, id, file_name, comp) do

            events =
            	comp["dispatched_by_component"]
            	|> Enum.filter(fn disp_comp -> disp_comp["type"] == "event" end)
            	|> Enum.map(fn event ->
              	"""
              	def handle_event({%FlowitScaffold.Event.#{Macro.camelize(event["name"])}{} = event, metadata}) do
                			state = get(event.stream_id) # Change this to whichever id you have on your read model
                			new_state = state
    									update_read_model_and_bookmark(event.stream_id, new_state, metadata)
    						end

    						"""
    						end)
          File.write!("#{id}/flowit_scaffold/read_models/#{file_name}.ex", """
          defmodule FlowitScaffold.ReadModel.#{Macro.camelize(file_name)} do
            use FlowitScaffold.ReadModel

            #{events}

						# catch all
            def handle_event({_, metadata}), do: update_bookmark(metadata)
            end
          """)

      end
  


  defp generate_event_file(app_name, id, file_name, comp) do
      		event_params = comp["event_params"] |> String.split(" ") |> Enum.map(fn x -> String.to_atom(x) end) |> Enum.filter(fn x ->  x != :"" end)

          params =
          case length(event_params) do
            0 -> [:stream_id]
            _ -> [:stream_id | event_params]
          end
          File.write!("#{id}/flowit_scaffold/events/#{file_name}.ex", """
          defmodule FlowitScaffold.Event.#{Macro.camelize(file_name)} do
            @derive Jason.Encoder
           defstruct #{inspect(params)}
          end
          """
          )
  end




  defp genereate_aggregates(_app_name, id, file_name, comp) do
          executes = Enum.map(comp["dispatched_by_component"], fn event ->
              [command] = event["dispatched_by_component"]

          """
          def execute(%Command.#{Macro.camelize(command["name"])}{} = cmd, state) do
            {:ok, %Event.#{Macro.camelize(event["name"])}{stream_id: cmd.stream_id} }
          end

          def apply_event(old_state, %Event.#{Macro.camelize(event["name"])}{} = event) do
						# Make the aggregate state a list of all events in scaffold. Can be used for simple vlaidation on whether an event exists
						case old_state do
  						nil -> [event]
  						x -> x ++ [event]
  						end
          end


          """

          end)

          File.write!("#{id}/flowit_scaffold/aggregates/#{file_name}.ex", """
          defmodule FlowitScaffold.Aggregate.#{Macro.camelize(file_name)} do
            use FlowitScaffold.Aggregate
            alias FlowitScaffold.Event
            alias FlowitScaffold.Command


            #{executes}
       		end
            """
            )
			end


	defp generate_command_file(app_name,id,file_name,comp) do
          dispatching_event = comp["dispatches"] |> Enum.find(fn x -> x["type"] == "event" end)
          aggregate = dispatching_event["aggregate"]

      		command_params = comp["command_params"] |> String.split(" ") |> Enum.map(fn x -> String.to_atom(x) end) |> Enum.filter(fn x ->  x != :"" end)
          params =
          case length(command_params) do
            0 -> [:stream_id]
            _ -> [:stream_id | command_params]
          end

         
          File.write!("#{id}/flowit_scaffold/commands/#{file_name}.ex", """
          defmodule FlowitScaffold.Command.#{Macro.camelize(file_name)} do
            @derive Jason.Encoder
           defstruct #{inspect(params)}

            defimpl FlowitScaffold.CommandDispatcher, for: FlowitScaffold.Command.#{Macro.camelize(file_name)} do
              def dispatch(command) do
                FlowitScaffold.Aggregate.#{Macro.camelize(aggregate)}.execute(command)
              end
            end
       end
            """
          )
      end

  defp generate_view_file(app_name, id, file_name, comp) do
		 	subscribing_read_models_mount =
            Enum.filter(comp["dispatched_by_component"], fn x -> x["type"] == "read_model" end)
            |> Enum.map(fn x -> x["name"] end)
            |> Enum.map(fn rm_name ->
              """
              	#{rm_name} = FlowitScaffold.ReadModel.#{Macro.camelize(rm_name)}.get_all()
              	:ok = FlowitScaffold.ReadModel.#{Macro.camelize(rm_name)}.subscribe_to_all()
              	socket = assign(socket, #{rm_name}: #{rm_name})
              """
            end)


          subscribing_read_models_handle_info =
            Enum.filter(comp["dispatched_by_component"], fn x -> x["type"] == "read_model" end)
            |> Enum.map(fn x -> x["name"] end)
            |> Enum.map(fn rm_name ->
              """
              def handle_info({FlowitScaffold.ReadModel.#{Macro.camelize(rm_name)}, id, state}, socket ) do
               new_read_model_state= Map.put(socket.assigns["#{rm_name}"], id, state)
                socket = assign(socket, "#{rm_name}", new_read_model_state)
                {:noreply, socket}
              end

             """
            end)


          subscribing_read_models_data =
            Enum.filter(comp["dispatched_by_component"], fn x -> x["type"] == "read_model" end)
            |> Enum.map(fn x -> x["name"] end)
            |> Enum.map(fn rm_name ->
              """
              <h2 class="font-xl"> #{Macro.camelize(rm_name)} </h2>
              <%= @#{rm_name} |> Jason.encode! %>

             """
            end)

          dispatching_commands_ui=
            Enum.filter(comp["dispatches"], fn x -> x["type"] == "command" end)
            |> Enum.map(fn x -> x["name"] end)
            |> Enum.map(fn command_name ->
              """
              <button class="mt-5 btn btn-primary" phx-click="#{command_name}"> #{command_name} </button>

              """
              end)

           dispatching_commands_handlers =
            Enum.filter(comp["dispatches"], fn x -> x["type"] == "command" end)
            |> Enum.map(fn x -> x["name"] end)
            |> Enum.map(fn command_name ->
              """
              def handle_event("#{command_name}", _, socket) do
                :ok = %FlowitScaffold.Command.#{Macro.camelize(command_name)}{stream_id: UUID.uuid1()}
                |> FlowitScaffold.CommandDispatcher.dispatch()
                {:noreply, socket}
                end

              """
              end)

          File.write!("#{id}/flowit_scaffold/views/#{file_name}.ex", """
          defmodule FlowitScaffold.View.#{Macro.camelize(file_name)} do
            use #{app_name}Web, :live_view

            def mount(_params, %{}, socket) do
              #{subscribing_read_models_mount}
              {:ok, socket}
            end

            #{dispatching_commands_handlers}

            #{subscribing_read_models_handle_info}

            def render(assigns) do
              ~H\"""
              <h1 class="text-2xl"> #{Macro.camelize(file_name)} </h1>

              #{subscribing_read_models_data}


              #{dispatching_commands_ui}
              \"""

            end
          end
          """)

  end





  defp nil_to_empty_array(nil), do: []
  defp nil_to_empty_array(x), do: x

  def get_aggregates(components) do
    (Enum.uniq_by(Enum.filter(components, fn comp -> comp["type"] == "aggregate" end), fn x -> x["name"] end ))
   end

  defp aggregate_height(i), do: (8 + 1.5 * i) * @height_unit

  defp event_height(event_component, aggregates) do
    IO.inspect aggregates
    Enum.find_index(aggregates, fn x -> x["name"] == event_component["aggregate"] end)
    |> aggregate_height
  end

  defp left_shift(_component, i), do: (4 + i) * @width_unit

  def render(assigns) do
    ~H"""

    <div class="shadow drawer drawer-mobile h-full min-h-screen w-full min-w-screen">
      <input id="my-drawer-2" type="checkbox" class="drawer-toggle">
      <div class="flex flex-col drawer-content">
        <div class="md:hidden">
          <label for="my-drawer-2" class="mb-4 btn btn-primary drawer-button lg:hidden">open
            menu</label>
        </div>
        <div class="hidden lg:block">
          <div class="md:p-8">
            <h1 class="text-3xl font-bold">Generate Flows</h1>
          </div>
          <div class="py-40">
            <%= case @flow do %><%= nil -> %><%= _ -> %>
            <%= flow_page(%{flow: @flow, aggregates: get_aggregates(@flow["components"]), myheight: 100}) %><%end %>
          </div>
        </div>
        <div class="text-xs text-center lg:hidden">
          Menu can be toggled on mobile size.<br>
          Resize the browser to see fixed sidebar on desktop size
        </div>
      </div>
      <div class="drawer-side">
        <ul class="menu p-4 overflow-y-auto w-80 bg-base-300 text-base-content">
            <%= if @flow do  %>
          	<h2 class="text-2xl mb-5"><%= @flow["name"] |> Macro.camelize() %> </h2>

            <%= add_component_modal_button(%{flow: @flow}, "Add View ", "btn-info btn-solid") %><%= add_component_modal_button(%{flow: @flow}, "Add Command", "btn-error") %>
            <%= add_component_modal_button(%{flow: @flow}, "Add Event", "btn-warning") %>
            <%= add_component_modal_button(%{flow: @flow}, "Add Read model", "btn-success" ) %><%= add_component_modal_button(%{flow: @flow},  "Add Processer", "btn-secondary" ) %>

            <%end %>

          <h2 class="text-2xl mb-5">Flows</h2>
            <div class="my-0 mx-0 py-0">
              <ul class="list-disc my-0 mx-0">
                <%= for flow <- Map.keys(@flows) do %>
                	<li> <%= link flow, to: "/flows/#{flow}" %></li>
                <%end %>
                <div class="flex justify-center">
                <label for="my-modal-3" class=" btn btn-primary modal-button btn-circle  text-2xl ">+</label>
                </div>
              </ul>
            </div>
            		<button phx-click="generate_counter_flow" class="mt-2 btn btn-neutral"> Generate counter flow</button>
            <form phx-submit="generate_files" class="mt-20">
            	<div class="form-control">
        				<label class="label"><span class="label-text">Your app name </span></label> <input name="app_name" type="text" placeholder="myApp" class= "input input-bordered">
            		<button type="submit" class="mt-2 btn btn-neutral"> Generate files </button>



            	</div>
            </form>
            </ul>
            </div>
            </div>


    <%= if @flow do %>
    	<%= for component <- @flow["components"] do %>
    		<%= if component["dispatched_by_id"] != nil  do %>
          <script>
            new LeaderLine(
              document.getElementById("<%= component["dispatched_by_id"]%>"),
              document.getElementById("<%= component["gui_id"] %>")
            );
          </script>

    		<%end %>
    	<%end %>
    <%end %>

    <input type="checkbox" id="my-modal-3" class="modal-toggle">
    <div class="modal">
      <div class="modal-box relative">
        <h3 class="text-lg font-bold">Create flow</h3>
        <form phx-submit="create_flow">
          <div class="form-control">
            <label class="label"><span class=
            "label-text">Filename</span></label> <input name="flowname" type="text" placeholder="myflow" class="input input-bordered">
          </div>
          <div class="modal-action">
            <label for="my-modal-3" class="btn">Cancel</label>
            <button for="my-modal-3" type="submit" class="btn btn-primary">Create</button>
          </div>
        </form>
      </div>
    </div>


    """
  end

  def flow_page(assigns) do
    ~H"""
    <%= add_component_modal(%{flow: @flow}, "Add View ", "add_view", fn x -> view_form_custom_conent(x) end ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Command", "add_command", fn x -> command_custom_form_custom_content(x) end, "btn-info" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Event", "add_event", fn x -> event_form_custom_content(x) end, "btn-warning" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Read model", "add_read_model", fn x -> read_model_custom_form_content(x) end, "btn-success" ) %>
    <%= add_component_modal(%{flow: @flow}, "Add Processer", "add_processer", fn x -> processer_custom_form_content(x) end, "btn-secondary" ) %>

    <div class="px-10 prose">
    <%= for {aggregate,i} <-

    Enum.with_index(Enum.uniq_by(Enum.filter(@flow["components"], fn comp -> comp["type"] == "aggregate" end), fn x -> x["name"] end )) do %>
     <div style={"position: absolute; top: #{aggregate_height(i)}px"} >
     <h3 class="text-2xl font-bold"> <%= Macro.camelize(aggregate["name"]) %> </h3>
     <div class="divider w-screen"></div>
     </div>
     <% end %>
     <div>


    <%= for {component,i} <- Enum.with_index(@flow["components"]) do %>
    <%=  case component["type"] do %>

    <%= "view" -> %>
    	<div id={component["gui_id"]}  class="flex bg-white border-4 text-center justify-center" style={"width:200px; height:200px; position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    	<h3 class="my-auto font-bold text-2xl"> <%= component["name"]  %> </h3>

    	</div>
    <%= "command" -> %>
    <div class="btn btn-info" id={component["gui_id"]} style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= component["name"] %>
    </div>

    <%= "event" -> %>
    <div class="btn btn-warning"  id={component["gui_id"]}   style={"position: absolute; top: #{event_height(component, @aggregates)}px; left: #{left_shift(component,i)}px"} >
    <%= component["name"] %>
    </div>

    <%= "processer" -> %>
    <div class="" id={component["gui_id"]}    style={"position: absolute; top: #{(1)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <img class="mx-auto" width="60px" src="https://pngset.com/images/gears-cogs-gear-vector-gray-world-of-warcraft-transparent-png-606080.png" />

    <%= (component["name"]) %>
    </div>

    <%= "read_model" -> %>
    <div id={component["gui_id"]} class="btn btn-success" style={"position: absolute; top: #{(4)*@myheight}px; left: #{left_shift(component,i)}px"} >
    <%= (component["name"]) %>
    </div>

    <%= _ -> %>
    <% end %>
    <% end %>

    </div>
    </div>
    """
  end

  def view_form_custom_conent(assigns) do
    ~H"""
                  <div class="form-control">
                    <label class="label"><span class=
                    "label-text">name</span></label> <input name="name"
                    type="text" placeholder="a_view"  class=
                    "input input-bordered">
                  </div>
    """
  end

  def add_component_modal_button(assigns, title, button_style) do
    ~H"""

    <div class="px-10 pb-5 ">
    <label for={title} class={"btn modal-button " <> button_style } >  <%= title %> </label>
    </div>
    """
  end

  def add_component_modal(assigns, title, submit, custom_content, button_style \\ "") do
    ~H"""

            <input type="checkbox" id={title} class="modal-toggle">
            <div class="modal ">
              <div class="modal-box zIndex">
              <div class="zIndex">
                <h4 class="text-xl font-bold"><%= title %> </h4>
                <form phx-submit={submit} >
                  <%= custom_content.(%{flow: @flow}) %>
                  <%= dispatched_by_select(%{flow: @flow}) %>
                  <div class="modal-action">
                    <button for={title} type="submit" class="btn btn-primary btn-md zIndex"> Create </button>
                    <label for={title} class="btn btn-md">Close</label>
                  </div>
                </form>
              </div>
              </div>
            </div>
    """
  end

  def dispatched_by_select(assigns) do
    ~H"""
    <div class="form-control">
    <label class="label mt-5"><span class="label-text">Dispatched
    by</span></label> <select name="dispatched_by_id" class=
    "select select-bordered w-full max-w-xs">
      <option selected="selected">
        None
      </option><%= for component <- @flow["components"]do %>
      <option value={component["gui_id"]}>
        <%= component["name"] %>
      </option><%end %>
    </select>
    </div>
    """
  end

  def read_model_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        read_model </span></label> <input name="read_model"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>
    """
  end

  def processer_custom_form_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class="label-text">
        Processer </span></label> <input name="processer"
        type="text" placeholder="payments" class=
        "input input-bordered">
        </div>

    """
  end

  def command_custom_form_custom_content(assigns) do
    ~H"""
    <div class="form-control">
    <label class="label"><span class=
    "label-text">Command</span></label> <input name="command"
    type="text" placeholder="pay" class= "input input-bordered">
    <label class="label"><span class=
    "label-text">Command params, space separated </span></label> <input name="command_params" type="text"  placeholder="amount reciever recipient" class="input input-bordered">
    </div>
    """
  end

  def event_form_custom_content(assigns) do
    ~H"""
      <div class="form-control">
        <label class="label"><span class=
        "label-text">Event name</span></label> <input name="event"
        type="text" placeholder="paid" class= "input input-bordered">

        <label class="label"><span class=
        "label-text">event params, space separated </span></label> <input name="event_params"
        type="text"  placeholder="amount reciever recipient" class=
        "input input-bordered">

        <label class="label"><span class=
        "label-text"> aggregate </span></label> <input name="aggregate"
        type="text"  placeholder="paymentaggregate" class=
        "input input-bordered">
      </div>

    """
  end


  defp generate_base(id, app_name) do
        File.write!("#{id}/flowit_scaffold/base/eventstore_db_client.ex", """
        defmodule FlowitScaffold.EventStoreDbClient do
          use Spear.Client,
            otp_app: :#{Macro.underscore(app_name)}
        end
        """)

        File.write!("#{id}/flowit_scaffold/base/command_dispatcher.ex", """
			defprotocol FlowitScaffold.CommandDispatcher do
        	def dispatch(command)
			end
        """)


        File.write!("#{id}/flowit_scaffold/base/helpers.ex", """
			defmodule FlowitScaffold.Helpers do

        def map_spear_event_to_domain_event(%Spear.Event{body: body, type: type, metadata: md} = spear_event) do
          try do
            ## this will give duplicated
            nil = spear_event.link
            body = Jason.decode!(body, keys: :atoms)
            IO.puts("event type is")
            IO.inspect(Macro.camelize(type))

            {Macro.camelize(type)
             |> String.to_existing_atom()
             |> struct(body), md}
          rescue
            e -> {%{}, md}
          end
        end

        def map_spear_event_to_domain_event(_event), do: {%{}, %{}}

        end
        """)
  end


  defp generate_supervisor(id, comps) do
    IO.inspect length(comps)
    read_models =
    Enum.filter(comps, fn comps-> comps["type"] == "read_model" end)
    |> IO.inspect
    |> Enum.map(fn rm ->
      """
      	FlowitScaffold.ReadModel.#{Macro.camelize(rm["name"])},
      """

      end)
      IO.puts "read models are"
    IO.inspect read_models

        File.write!("#{id}/flowit_scaffold/base/supervisor.ex", """

      defmodule FlowitScaffold.Supervisor do
        use Supervisor

        def start_link(init_arg) do
          Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end

        @impl true
        def init(_init_arg) do
          children = [
      			{Phoenix.PubSub, name: FlowitScaffold.PubSub},
      			FlowitScaffold.EventStoreDbClient,
      			{DynamicSupervisor, strategy: :one_for_one, name: FlowitScaffold.AggregateSupervisor},
      			{Registry, keys: :unique, name: FlowitScaffold.AggregateRegistry},
      			#{read_models}
          ]
          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      """
      )

  end

  defp generate_read_model_macro(id) do
          File.write!("#{id}/flowit_scaffold/base/read_model_macro.ex", """
defmodule FlowitScaffold.ReadModel do
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger

      def subscribe(id) do
        Phoenix.PubSub.subscribe(FlowitScaffold.PubSub, to_string(__MODULE__) <> ":" <> id)
      end

      def subscribe_to_all() do
        Phoenix.PubSub.subscribe(FlowitScaffold.PubSub, to_string(__MODULE__))
      end

      def broadcast(id, state) do
        Phoenix.PubSub.broadcast(FlowitScaffold.PubSub, to_string(__MODULE__) <> ":" <> id, {__MODULE__, id, state})
      end

      def broadcast_to_all(id, state) do
        Phoenix.PubSub.broadcast(FlowitScaffold.PubSub, to_string(__MODULE__), {__MODULE__, id, state})
      end

      def start_link(args) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init([]) do
        :ets.new(__MODULE__, [:set, :named_table, :public])
        # File.mkdir("dets_storage")
        # :dets.open_file("dets_storage/#{__MODULE__}", [])
        last_event = get_last_event()
        {:ok, sub} = subscribe_all(:start)
        {:ok, %{}}
      end

      def get(id) do
        :ets.lookup(__MODULE__, id)
        |> case do
          [] -> nil
          [{_id, data}] -> data
        end
      end

      def get_all() do
        :ets.tab2list(__MODULE__)
        |> Enum.filter(fn {key, elem} -> String.contains?(key, "bookmark") == false end)
        |> Enum.map(fn {key, elem} -> elem end)
      end

      def get_bookmark(stream_name) do
        :ets.lookup(__MODULE__, "bookmark:\#{inspect stream_name}")
        |> case do
          [{_id, number}] ->
            number

          [] -> nil
            # :dets.lookup(__MODULE__, "bookmark:\#{inspect stream_name}")
            # |> case do
            #   [] ->
            #     nil

            #   [{_id, number}] ->
            #     :ets.insert(__MODULE__, {"bookmark:\#{inspect stream_name}", number})
            #     number
            # end
        end
      end

      def get_last_event(), do: :start

      def set(id, data, stream) do
        :ets.insert(__MODULE__, {id, data})
      end

      def select(fun) do
        :ets.select(__MODULE__, fun)
      end

      def update_read_model_and_bookmark(rm_id, rm_data, metadata),
        do: update_read_model_and_bookmark(rm_id, rm_data, metadata.stream_name, metadata.stream_revision)

      def update_read_model_and_bookmark(rm_id, rm_data, stream_name, revision) do
        :ets.insert(__MODULE__, [{rm_id, rm_data}, {"bookmark:\#{inspect stream_name}", revision}])
        broadcast(rm_id, rm_data)
        broadcast_to_all(rm_id,rm_data)
        :ok
      end

      def update_bookmark(metadata) do
        true = :ets.insert(__MODULE__, [{"bookmark:\#{inspect metadata.stream_name}", metadata.stream_revision}])
        :ok
      end

      defp subscribe_all(from),
        do:
          Spear.subscribe(FlowitScaffold.EventStoreDbClient, self(), :all,
            from: from,
            filter: Spear.Filter.exclude_system_events()
          )

      def handle_info(%Spear.Event{} = event, _state) do

        get_bookmark(event.metadata.stream_name)
        |> case do
          nil when event.metadata.stream_revision == 0 -> 0
          x when x + 1 == event.metadata.stream_revision -> x + 1
          x when x == event.metadata.stream_revision -> :already_handled
          x -> raise "bookmark is \#{x} and stream revision is \#{event.metadata.stream_revision} out of order"
        end
        |> case do
          :already_handled ->
            {:noreply, _state}

          new_revision ->
            {domain_event, metadata} = FlowitScaffold.Helpers.map_spear_event_to_domain_event(event)
            :ok = handle_event({domain_event, metadata})
            ## send event revision as a
        end

        {:noreply, _state}
      end

      def handle_info(_, state), do: {:noreply, state}
    end
  end
end

"""
)

end



  defp generate_aggregate_macro(id) do
          File.write!("#{id}/flowit_scaffold/base/aggregate_macro.ex", """

defmodule FlowitScaffold.Aggregate do
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger

      def start_link(args) do
        [stream_id: stream_id, name: name] = args

        cond do
          stream_id == "" ->
            {:error, "stream_id cant be empty"}

          stream_id == nil ->
            {:error, "stream_id cant be empty"}

          true ->
            GenServer.start_link(__MODULE__, [to_string(__MODULE__)<>":" <> stream_id],
              name: name
            )
        end
      end

      def execute(command) do
        {:ok, pid} = find_or_start_aggregate_agent(command.stream_id)
        GenServer.call(pid, {:execute, command})
      end

      def init([stream_id]) do
        GenServer.cast(self(), :finish_init)
        {:ok, {stream_id, nil, 0}}
      end

      def handle_cast(:finish_init, {stream_id, nil, 0}) do
        {:ok, events} = Spear.read_stream(FlowitScaffold.EventStoreDbClient, stream_id, max_count: 99999)

        domain_events =
          Enum.map(events, fn event ->
            {domain_event, _} = FlowitScaffold.Helpers.map_spear_event_to_domain_event(event)
            domain_event
          end)

        state =
          Enum.reduce(domain_events, nil, fn domain_event, state ->
            apply_event(state, domain_event)
          end)

        {:noreply, {stream_id, state, length(domain_events)}}
      end

      def handle_call(
            {:execute, command},
            _from,
            {stream_id, state, event_nr}
          ) do
        with {:ok, event} <- execute(command, state),
             _ <- IO.inspect(event),
             spear_event <-
               Spear.Event.new("\#{(event.__struct__)}", Jason.encode!(event)),
             :ok <- Spear.append([spear_event], FlowitScaffold.EventStoreDbClient, stream_id, expect: event_nr - 1) do
          new_state = apply_event(state, event)
          {:reply, :ok, {stream_id, new_state, event_nr + 1}}
        else
          err ->
            Logger.error("Something went wrong writing event \#{inspect(err)}")
            {:reply, err, {stream_id, state, event_nr}}
        end
      end

      def find_or_start_aggregate_agent(stream_id) do
        Registry.lookup(FlowitScaffold.AggregateRegistry, stream_id)
        |> case do
          [{pid, _}] ->
            {:ok, pid}

          [] ->
            spec = {__MODULE__, stream_id: stream_id, name: {:via, Registry, {FlowitScaffold.AggregateRegistry, stream_id}}}
            DynamicSupervisor.start_child(FlowitScaffold.AggregateSupervisor, spec)
        end
      end
    end
  end
end
""")



end
end
